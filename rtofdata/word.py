from datetime import datetime
from pathlib import Path

from docx.shared import Cm
from docxtpl import DocxTemplate, InlineImage

import git

from rtofdata.config import assets_dir, data_dir, output_dir


def write_word_specification(data: dict, filename: str):
    """
    Creates a detailed Word version of the specification.
    Read more about docx here: https://python-docx.readthedocs.io/en/latest/
    """

    tpl = DocxTemplate(assets_dir / "template.docx")

    repo = git.Repo(search_parent_directories=True)
    git_version = repo.head.object.hexsha[:7]

    tagmap = {}
    for t in repo.tags:
        tagmap.setdefault(repo.commit(t), []).append(t)

    git_tag = tagmap.get(repo.head.object)
    if git_tag:
        git_version = str(git_tag[0])

    if repo.is_dirty() or len(repo.untracked_files) > 0:
        git_version = f"{git_version} (changes pending)"

    context = dict(git_version=git_version, generation_time=f"{datetime.now():%-d %B %Y}")

    context['milestones_image'] = InlineImage(tpl, image_descriptor=str(assets_dir / 'RTOF_program_path.png'),
                                              width=Cm(16))

    context['record_list'] = record_list = [{**t} for t in data['Tables']]
    for record in record_list:
        record['fields'] = [f for f in data['Fields'] if f['Table'] == record['Table']]

    context['field_list'] = field_list = [{**t} for t in data['Fields']]
    for field in field_list:
        field['table'] = [t for t in data['Tables'] if t['Table'] == field['Table']]

    field_list.sort(key=lambda f: f"{f['Table']}.{f['ID']}")

    tpl.render(context)
    tpl.save(output_dir / "specification.docx")
