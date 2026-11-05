#!/usr/bin/env python3
"""iPhoto Project Manager – routes GitHub issues to actors via Claude."""

import json
import os
import subprocess
import sys

import anthropic

ACTORS_FILE = ".github/actors.json"
DRY_RUN = "--dry-run" in sys.argv

api_key = os.environ.get("ANTHROPIC_API_KEY", "")
if not api_key:
    print("FEHLER: ANTHROPIC_API_KEY ist nicht gesetzt.", file=sys.stderr)
    sys.exit(1)
print(f"API-Key: {api_key[:8]}… (Länge {len(api_key)})")
client = anthropic.Anthropic(api_key=api_key)


def gh(*args: str) -> str:
    result = subprocess.run(["gh", *args], capture_output=True, text=True, check=True)
    return result.stdout.strip()


def load_actors() -> list[dict]:
    with open(ACTORS_FILE) as f:
        return json.load(f)["actors"]


def save_actors(actors: list[dict]) -> None:
    if DRY_RUN:
        return
    with open(ACTORS_FILE, "w") as f:
        json.dump({"actors": actors}, f, indent=2, ensure_ascii=False)
        f.write("\n")


def get_unrouted_issues() -> list[dict]:
    # Fetch all open issues via pagination so no issue is missed
    raw = gh(
        "api", "--paginate",
        "/repos/{owner}/{repo}/issues",
        "-X", "GET",
        "-f", "state=open",
        "-f", "per_page=100",
    )
    # --paginate outputs one JSON array per page; merge them
    pages = []
    decoder = json.JSONDecoder()
    pos = 0
    raw = raw.strip()
    while pos < len(raw):
        raw_slice = raw[pos:].lstrip()
        if not raw_slice:
            break
        obj, offset = decoder.raw_decode(raw_slice)
        pages.extend(obj if isinstance(obj, list) else [obj])
        pos += len(raw) - len(raw_slice) + offset

    # Sort: priority:high first, then by number ascending (oldest first)
    def sort_key(i: dict) -> tuple:
        labels = [l["name"] for l in i.get("labels", [])]
        is_high = "priority: high" not in labels
        return (is_high, i["number"])

    unrouted = [
        i for i in pages
        if not i.get("pull_request")  # skip PRs
        and not any(l["name"].startswith("actor:") for l in i.get("labels", []))
    ]
    return sorted(unrouted, key=sort_key)


def ensure_label(name: str, description: str) -> None:
    if DRY_RUN:
        return
    try:
        gh("label", "create", name,
           "--color", "5319e7",
           "--description", description[:100])
    except subprocess.CalledProcessError:
        pass  # already exists


def route_issue(issue: dict, actors: list[dict]) -> dict:
    actors_block = "\n".join(
        f"- id={a['id']}  name={a['name']}  rolle={a['description']}"
        for a in actors
    ) or "(noch keine Akteure – erfinde den ersten)"

    prompt = f"""Du bist der autonome Project Manager des iPhoto-Projekts.
iPhoto ist ein nativer macOS RAW-Editor (Swift/SwiftUI) speziell für Fuji-Kameras.
Er hat eine Swift-App, einen Rust/FFI-Core, SQLite-Katalog, ~55 CLI-Subcommands.

Bereits existierende Akteure:
{actors_block}

Offener GitHub Issue #{issue["number"]}:
Titel: {issue["title"]}
Body:
{(issue.get("body") or "(kein Body)").strip()[:1200]}

Entscheide:
1. Welcher Akteur ist für diesen Issue zuständig?
   – Wähle einen existierenden, wenn er gut passt.
   – Erfinde einen neuen, wenn keiner wirklich passt (Fokus scharf halten, keine Generalist-Akteure).
2. Schreibe eine klare Direktive (Aufgabe + Kontext + Erwartetes Ergebnis, 3–5 Sätze, Deutsch).

Antworte AUSSCHLIESSLICH mit gültigem JSON, kein Markdown drum herum:
{{
  "actor_id": "kebab-case-eindeutige-id",
  "actor_name": "Lesbarer Name",
  "actor_description": "Eine-Satz-Rollenbeschreibung",
  "is_new": true,
  "directive": "Konkrete Aufgabe für den Akteur zu diesem Issue."
}}"""

    response = client.messages.create(
        model="claude-opus-4-7",
        max_tokens=600,
        messages=[{"role": "user", "content": prompt}],
    )
    text = response.content[0].text.strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    return json.loads(text.strip())


def post_directive(issue_number: int, assignment: dict) -> None:
    new_flag = " *(neu erstellt)*" if assignment.get("is_new") else ""
    body = (
        f"## 📋 Direktive — ProjectManager\n\n"
        f"**Akteur:** {assignment['actor_name']}{new_flag}  \n"
        f"**Rolle:** {assignment['actor_description']}  \n\n"
        f"### Aufgabe\n\n"
        f"{assignment['directive']}\n\n"
        f"---\n"
        f"*Automatisch zugewiesen · `actor:{assignment['actor_id']}`*"
    )
    if DRY_RUN:
        print(f"  [dry-run] Kommentar an #{issue_number}:\n{body[:200]}…")
        return
    gh("issue", "comment", str(issue_number), "--body", body)


def main() -> None:
    if DRY_RUN:
        print("=== DRY-RUN (kein GitHub-Write) ===")

    actors = load_actors()
    issues = get_unrouted_issues()

    if not issues:
        print("Keine ungerouteten Issues.")
        return

    print(f"{len(issues)} ungeroutete Issue(s) gefunden.")

    for issue in issues:
        print(f"\nIssue #{issue['number']}: {issue['title']}")

        try:
            assignment = route_issue(issue, actors)
        except Exception as exc:
            print(f"  FEHLER (Claude) [{type(exc).__name__}]: {exc}", file=sys.stderr)
            continue

        # Persist new actor immediately so it's not lost on later failure
        if assignment.get("is_new"):
            actors.append({
                "id": assignment["actor_id"],
                "name": assignment["actor_name"],
                "description": assignment["actor_description"],
            })
            save_actors(actors)
            print(f"  + Neuer Akteur: {assignment['actor_name']}")

        label = f"actor:{assignment['actor_id']}"
        ensure_label(label, assignment["actor_description"])

        try:
            if not DRY_RUN:
                gh("issue", "edit", str(issue["number"]), "--add-label", label)
        except subprocess.CalledProcessError as exc:
            print(f"  Label-Fehler: {exc}", file=sys.stderr)
            continue

        try:
            post_directive(issue["number"], assignment)
        except subprocess.CalledProcessError as exc:
            print(f"  Direktive-Fehler: {exc}", file=sys.stderr)
            # Label is already set — issue won't be re-processed next run

        print(f"  → {assignment['actor_name']} ({label})")

    print(f"\nFertig. {len(actors)} Akteure in Registry.")


if __name__ == "__main__":
    main()
