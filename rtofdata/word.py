from dataclasses import asdict
from datetime import datetime
from typing import List

from docx.shared import Cm
from docxtpl import DocxTemplate, InlineImage

import git

from rtofdata.config import assets_dir, output_dir
from rtofdata.spec_parser import Record, Specification


def get_git_version():
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

    return git_version


def create_context(spec: Specification):
    context = {
        "git_version": get_git_version(),
        "generation_time": f"{datetime.now():%d %B %Y}",
        "record_list": spec.records,
    }

    context['field_list'] = field_list = []
    for record in spec.records:
        for field in record.fields:
            field_list.append({**asdict(field), "record": record})
    field_list.sort(key=lambda f: f"{f['record']}.{f['id']}")

    return context


def write_word_specification(spec: Specification):
    """
    Creates a detailed Word version of the specification.
    Read more about docx here: https://python-docx.readthedocs.io/en/latest/
    """

    tpl = DocxTemplate(assets_dir / "template.docx")
    context = create_context(spec)
    context['milestones_image'] = InlineImage(tpl, image_descriptor=str(assets_dir / 'submission_and_collection.png'),
                                              width=Cm(16))

    tpl.render(context)
    tpl.save(output_dir / "specification.docx")

    tpl1 = DocxTemplate(assets_dir / "template.docx")
    context = create_context(spec)
    context['milestones_image2'] = InlineImage(tpl, image_descriptor=str(assets_dir / 'Data_forms_to_be_submitted.png'),
                                              width=Cm(16))
    tpl1.render(context)
    tpl1.save(output_dir / "specification.docx")    
