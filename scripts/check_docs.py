"""Validate the reviewed documentation path without external dependencies."""
from pathlib import Path
import ast
import re
from build_master_guide import CHAPTERS, ROOT, build

paths = {ROOT/'README.md', ROOT/'Fullstack-Master-Interview-Guide.md',
         ROOT/'interview-prep/README.md', ROOT/'interview-prep/SOURCES-AND-REVIEW.md',
         ROOT/'interview-prep/09-deep-dive/README.md'}
paths.update(ROOT/'interview-prep'/relative for _,relative in CHAPTERS)
paths.update((ROOT/'postgres-practice').glob('*.md'))
errors=[]; links=0; python_blocks=0
for path in sorted(paths):
    source=path.read_text()
    if source.count('```')%2:
        errors.append(f'{path.name}: unbalanced code fences')
    prose=re.sub(r'```[^\n]*\n.*?```','',source,flags=re.S)
    for dest in re.findall(r'\]\(([^)]+)\)',prose):
        if dest.startswith(('http://','https://','mailto:')):
            continue
        target,_,anchor=dest.partition('#')
        if target and not (path.parent/target).exists():
            errors.append(f'{path.relative_to(ROOT)}: missing {dest}')
        if not target and anchor.startswith('chapter-') and f'id="{anchor}"' not in source:
            errors.append(f'{path.name}: missing anchor {anchor}')
        links+=1
    # Parse source chapters only, not their duplicated master copy.
    if path.name!='Fullstack-Master-Interview-Guide.md':
        for block in re.findall(r'```python\n(.*?)```',source,re.S):
            try: ast.parse(block); python_blocks+=1
            except SyntaxError as error: errors.append(f'{path.name}: {error}')
if (ROOT/'Fullstack-Master-Interview-Guide.md').read_text()!=build():
    errors.append('Master guide out of sync')
print(f'{len(paths)} files; {links} local links; {python_blocks} Python snippets parsed')
if errors:
    raise SystemExit('\n'.join(errors))
print('Documentation checks passed')
