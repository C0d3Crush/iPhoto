#!/usr/bin/env python3
"""iPhoto Project Manager – routes GitHub issues to actors via Claude."""

import json
import os
import subprocess
import sys

import anthropic

ACTORS_FILE = ".github/actors.json"
client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])


def gh(*args: str) -> str:
    result = subprocess.run(["gh", *args], capture_output=True, text=True, check=True)
    return result.stdout.strip()


def load_actors() -> list[dict]:
    with open(ACTORS_FILE) as f:
        return json.load(f)["actors"]


def save_actors(actors: list[dict]) -> None:
    with open(ACTORS_FILE, "w") as f:
        json.dump({"actors": actors}, f, indent=2, ensure_ascii=False)
        f.write("\n")


def get_unrouted_issues() -> list[dict]:
    raw = gh(
        "issue", "list",
        "--state", "open",
        "--json", "number,title,body,labels",
        "--limit", "50",
    )
    issues = json.loads(raw)
    return [
        i for i in issues
        if not any(lbl["name"].startswith("actor:") for lbl in i["labels"])
    ]


def ensure_label(name: str, description: str) -> None:
    """Create label if it doesn't exist yet (silently ignores duplicates)."""
    try:
        gh("label", "create", name,
           "--color", "5319e7",
           "--description", description[:100])
    except subprocess.CalledProcessError:
        pass


def route_issue(issue: dict, actors: list[dict]) -> dict:
    """Ask Claude to assign an actor and write a directive. Returns assignment dict."""
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
    # Strip accidental markdown fences
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    return json.loads(text.strip())


def post_directive(issue_number: int, assignment: dict) -> None:
    new_flag = " *(neu erstellt)*" if assignment["is_new"] else ""
    body = (
        f"## 📋 Direktive — ProjectManager\n\n"
        f"**Akteur:** {assignment['actor_name']}{new_flag}  \n"
        f"**Rolle:** {assignment['actor_description']}  \n\n"
        f"### Aufgabe\n\n"
        f"{assignment['directive']}\n\n"
        f"---\n"
        f"*Automatisch zugewiesen · `actor:{assignment['actor_id']}`*"
    )
    gh("issue", "comment", str(issue_number), "--body", body)


def main() -> None:
    actors = load_actors()
    issues = get_unrouted_issues()

    if not issues:
        print("Keine ungerouteten Issues.")
        return

    actors_changed = False

    for issue in issues:
        print(f"\nIssue #{issue['number']}: {issue['title']}")

        try:
            assignment = route_issue(issue, actors)
        except Exception as exc:
            print(f"  FEHLER (Claude): {exc}", file=sys.stderr)
            continue

        # Register new actor if invented
        if assignment.get("is_new"):
            actors.append({
                "id": assignment["actor_id"],
                "name": assignment["actor_name"],
                "description": assignment["actor_description"],
            })
            actors_changed = True
            print(f"  + Neuer Akteur: {assignment['actor_name']}")

        label = f"actor:{assignment['actor_id']}"
        ensure_label(label, assignment["actor_description"])

        try:
            gh("issue", "edit", str(issue["number"]), "--add-label", label)
        except subprocess.CalledProcessError as exc:
            print(f"  Label-Fehler: {exc}", file=sys.stderr)
            continue

        post_directive(issue["number"], assignment)
        print(f"  → {assignment['actor_name']} ({label})")

    if actors_changed:
        save_actors(actors)
        print(f"\nactors.json: {len(actors)} Akteure gespeichert.")


if __name__ == "__main__":
    main()
