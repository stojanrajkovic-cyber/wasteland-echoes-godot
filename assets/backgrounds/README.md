Drop background images here, named to match each prompt's "imageName"
field from data/prompts.json, e.g. day3_prompt_triage.jpg for the prompt
with "imageName": "day3_prompt_triage". .jpg or .png both work.

game_view.gd checks for these at runtime and falls back to a plain dark
color if a specific image isn't here yet - so the story is fully
playable before art is ported, and art can be dropped in later without
any code changes.
