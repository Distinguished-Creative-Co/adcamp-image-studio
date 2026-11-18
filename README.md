# AdCamp Image Studio

Make images and finished graphics for your ads, carousels, posts and thumbnails. You describe what you want. Your Claude writes the prompt, Codex (ChatGPT) makes the picture on your own Mac, and your Claude checks it before you see it.

## What you need

- A Mac.
- The Claude desktop app, with Claude working on your Mac itself. That is the Code tab with a folder on your Mac open.
- A ChatGPT account. Making images may need a paid ChatGPT plan.

## How to install

Open the Claude desktop app, go to the Code tab, start a new chat and paste this. It looks technical, but you do not need to understand it. Just paste it:

```
Install AdCamp Image Studio for me from https://github.com/Distinguished-Creative-Co/adcamp-image-studio (download it as a tar.gz with curl, not with git, into a temporary folder), then run the install.sh inside it. Tell me what each step does before it runs, and ask me before anything that needs an account, a password, or a choice from me. When it is done, remind me to start a new chat and say: Set up Image Studio
```

To update later, paste the same thing again. Your pictures and brand card are kept.

## How to start

Start a new chat and tell your Claude:

> Set up Image Studio

Claude will ask your permission before it runs anything on your Mac. That is normal. It checks your Mac, helps you get Codex if you do not have it, and asks four short questions about your brand. Then say what you want:

> Make me an image for a feed ad. A bright adjusting room, no people.

## Things you can say

- "Make me an image for my ad"
- "Make a carousel background"
- "Make an ad image of a woman stretching her neck at her desk"
- "Make a thumbnail"
- "Give me three image ideas"
- "Make it warmer" or "try another version"
- "Make a graphic that says New Patient Special"
- "What do you think of this design"

## Where your pictures go

A folder named `AdCamp Image Studio` in your home folder, inside `images`.

## Good to know

- Your prompts and any pictures you share as a reference go to OpenAI, under your own ChatGPT account.
- Each picture uses some of your ChatGPT plan. So does each second look. If a picture comes out wrong, your Claude may try again, up to two more times, and it tells you when it does.
- Pictures with words in them get a spelling check before you see them. If the words will not come out right, your Claude offers a clean picture you can add words to in AVS or Canva.
- Whether an image is OK to run as an ad is a question for your AdCamp coach.
- Mac only for now.
