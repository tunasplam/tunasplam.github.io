# Webpage

## Developing

Based on Chirpy Starter

### Preview

This starts up live reload that can be accessed at [127.0.0.1:4000](127.0.0.1:4000) where drafts are included. Any article in the `drafts` directory would not normally be served on the public facing site and are considered "in staging".

`sudo bundle exec jekyll serve --livereload --drafts`

## Tools at your Disposal

### Admonitions

Admonitions, or callout boxes, can be created with varying styles. An example of one is below.

```javascript
{% include admonition.html type="names-note" title="The Meaning of Names" content="
Hesse chose the names of his characters to highlight their purpose in the narrative. Boxes like these will contain the results of a cursory dive into a Sanskrit dictionary to shed some light on the meaning of these names."
%}
```

A new type of admonition can be defined in `assets/css/jekyll-theme-chirpy.scss` by defining its type and the text which precedes the content.

```scss
.admonition-names-note {
  padding: 1em;
  border-left: 6px solid;
  border-right: 6px solid;
  margin: 1.5em 0;
  border-radius: 6px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.05);

  border-color: #c09f0a;
  background-color: #3b6828;
  color: #e9e7e7;
}

.admonition-names-note .admonition-title::before {
  content: "✒️ Name Note -  ";
}
```

### Images

You can right- or left-align images and specify the percentage of the screen width that you wish them to fill. Organize images into sensible directories under `assets/img/`.

```javascript
{% include image.html
   src="assets/img/zen-ox-herding/img1.png"
   alt="Not found!"
   caption="A depiction of a man seeking a bull."
   source="Wikimedia Commons, Public domain"
   align="right"
   width="40%"
%}
```

### Centered-quotes

Useful for poetry, these quotes center their text, respect line breaks, and have highlight bars which can be moved from the left to the right. This is useful when places side-by-side with a left aligned figure.

```javascript
{% include centered-quote.html content="
Along the riverbank under the trees, I discover footprints.
Even under the fragrant grass, I see his prints.
Deep in remote mountains they are found.
These traces can no more be hidden than one's nose, looking heavenward.
" right_bar=true
%}
```

### TODO Ideas

- Maybe music connection admonition. Things where major modern works were influenced by something.
- "Currently reading" information on left side bar.
- Sections on right side bar should spill to next line instead of truncating.
- Restyle the admonitions boxes and predefine several color schemes that can be used with them. There needs to be both light and dark mode theme.

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
