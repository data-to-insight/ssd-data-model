from dataclasses import asdict
from datetime import datetime
from typing import List

from docx.shared import Cm
from docxtpl import DocxTemplate, InlineImage

import git

from rtofdata.config import assets_dir, output_dir
from rtofdata.spec_parser import Record


def write_word_specification(record_list: List[Record]):
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

    context['record_list'] = record_list

    context['field_list'] = field_list = []
    for record in record_list:
        for field in record.fields:
            field_list.append({**asdict(field), "record": record})

    field_list.sort(key=lambda f: f"{f['record']}.{f['id']}")

    tpl.render(context)
    tpl.save(output_dir / "specification.docx")
