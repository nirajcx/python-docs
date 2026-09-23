"""Build root master from reviewed chapters; stdlib only, no external writes."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
CHAPTERS = [
 ('Python fundamentals', '00-start-here/01-python-quick-guide.md'),
 ('Python OOP, runtime and async depth', '09-deep-dive/08-python-deeper-concepts.md'),
 ('JavaScript core', '00-start-here/10-javascript-fundamentals-guide.md'),
 ('JavaScript declarations and language depth', '09-deep-dive/01-javascript-language.md'),
 ('TypeScript contracts', '00-start-here/11-typescript-guide.md'),
 ('HTTP and FastAPI fundamentals', '00-start-here/02-fastapi-quick-guide.md'),
 ('Backend production patterns and ORM', '09-deep-dive/05-backend-production-patterns.md'),
 ('JWT, sessions, authentication and security', '09-deep-dive/02-auth-jwt-sessions.md'),
 ('SQL and database fundamentals', '00-start-here/04-database-quick-guide.md'),
 ('PostgreSQL index internals and query tuning', '09-deep-dive/03-postgres-indexing-internals.md'),
 ('React core and hooks', '00-start-here/03-react-nextjs-quick-guide.md'),
 ('React, browser, forms and frontend depth', '09-deep-dive/06-react-browser-engineering.md'),
 ('API and production debugging', '09-deep-dive/04-api-production-debugging.md'),
 ('System design with worked diagrams', '00-start-here/05-system-design-quick-guide.md'),
 ('Operations, distributed systems and advanced electives', '09-deep-dive/07-system-operations-advanced.md'),
 ('Coding, SQL, mock questions and scorecard', '00-start-here/12-scenario-coding-round.md'),
 ('Coverage checklist and follow-up question bank', '09-deep-dive/09-interview-coverage.md'),
]

def chapter_body(path):
    """Rewrite only prose links/headings; preserve code fence contents verbatim."""
    lines = path.read_text().splitlines()
    out, fenced = [], False
    for i, line in enumerate(lines):
        if i == 0 and line.startswith('# '):
            continue
        if line.startswith('```'):
            fenced = not fenced
        if not fenced and not line.startswith('```'):
            def link(match):
                destination = match.group(1)
                if destination.startswith(('https://', 'http://', '#', 'mailto:')):
                    return match.group(0)
                file, sep, anchor = destination.partition('#')
                target = (path.parent / file).resolve().relative_to(ROOT).as_posix()
                return '](' + target + (sep + anchor if sep else '') + ')'
            line = re.sub(r'\]\(([^)]+)\)', link, line)
            if line.startswith('#'):
                line = '#' + line
        out.append(line)
    return '\n'.join(out).strip()

def build():
    sections = [
        '# Full-Stack Master Interview Guide — FastAPI + React + PostgreSQL\n',
        '**Target:** 2.5 years actual experience, preparation at 3-year full-stack depth. **Language:** Hinglish. **Reviewed:** 23 September 2026.\n',
        'Core definitions se practical debugging, concurrency, auth, system design aur advanced follow-ups tak. Har topic ko mechanism + example + trade-off + failure/test ke saath prepare karo. Exact employer questions guarantee nahi; priority actual job description ke according adjust karo.\n',
        '**How to use:** [Roadmap](interview-prep/README.md) → chapters below → [PostgreSQL hands-on folder](postgres-practice/README.md) → mock. P0 fundamentals, P1 practical depth, P2 role-specific internals.\n',
        '**Single source:** this file is generated from the linked reviewed chapter files using `python3 scripts/build_master_guide.py`. Edit those chapters, then rebuild; `--check` detects drift. Earlier duplicated claims and unverified first-person project metrics have been replaced with qualified explanations and practice templates. Existing PDF, if present, is not this revision.\n',
        '**Scope and validation:** [Audit and official sources](interview-prep/SOURCES-AND-REVIEW.md). Illustrative snippets are labelled; this is a study guide, not a complete production app.\n',
        '## Contents\n',
    ]
    for number,(title,_) in enumerate(CHAPTERS,1):
        sections.append(f'{number}. [{title}](#chapter-{number:02d})')
    for number,(title,relative) in enumerate(CHAPTERS,1):
        path=ROOT/'interview-prep'/relative
        sections.extend(['\n---\n', f'<a id="chapter-{number:02d}"></a>\n',
                         f'## {number}. {title}\n',
                         f'Source chapter: [{path.name}](interview-prep/{relative})\n',
                         chapter_body(path)])
    return '\n'.join(sections)+'\n'

if __name__ == '__main__':
    output = ROOT/'Fullstack-Master-Interview-Guide.md'
    text = build()
    if '--check' in sys.argv:
        if output.read_text()!=text:
            raise SystemExit('Master guide differs: run python3 scripts/build_master_guide.py')
        print('Master guide matches all reviewed source chapters.')
    else:
        output.write_text(text)
        print(f'Built {output.name}: {len(CHAPTERS)} chapters, {len(text.splitlines())} lines')
