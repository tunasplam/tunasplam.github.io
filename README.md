# Webpage

## My notes

Based on Chirpy Starter

### Preview

This starts up live reload that can be accessed at [127.0.0.1:4000](127.0.0.1:4000) where drafts are included. Any article in the `drafts` directory would not normally be served on the public facing site and are considered "in staging".

`sudo bundle exec jekyll serve --livereload --drafts`

### TODO Ideas

- Maybe music connection admonition. Things where major modern works were influenced by something.
- "Currently reading" information on left side bar.
- Sections on right side bar should spill to next line instead of truncating.

## Chirpy-Starter info (was already here)

When installing the [**Chirpy**][chirpy] theme through [RubyGems.org][gem], Jekyll can only read files in the folders
`_data`, `_layouts`, `_includes`, `_sass` and `assets`, as well as a small part of options of the `_config.yml` file
from the theme's gem. If you have ever installed this theme gem, you can use the command
`bundle info --path jekyll-theme-chirpy` to locate these files.

The Jekyll team claims that this is to leave the ball in the user’s court, but this also results in users not being
able to enjoy the out-of-the-box experience when using feature-rich themes.

To fully use all the features of **Chirpy**, you need to copy the other critical files from the theme's gem to your
Jekyll site. The following is a list of targets:

```shell
.
├── _config.yml
├── _plugins
├── _tabs
└── index.html
```

To save you time, and also in case you lose some files while copying, we extract those files/configurations of the
latest version of the **Chirpy** theme and the [CD][CD] workflow to here, so that you can start writing in minutes.

## Usage

Check out the [theme's docs](https://github.com/cotes2020/jekyll-theme-chirpy/wiki).


