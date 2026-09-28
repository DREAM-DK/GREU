# Layout mockups - with the graphic system

The same seven pages as [../mockups](../mockups), the same copy, and the same
Direction 05 palette. The difference is that this set uses the **connected
discs** and the **squared grid** from the brand lab, instead of leaving the
pages plain.

Put the two side by side to decide how much graphic the site should carry.
Neither is the GoBasic theme.

**To view:** double-click `index.html`.

## Where the graphic comes from

`brand-lab/backgrounds/05-dream-heritage.svg` and
`brand-lab/generated/dream-heritage-study.png`: DREAM's model discs, each in
its own colour, joined by thin lines on a faint grid, with the international
model as the largest disc. The topology and the colours here are unchanged
from that file.

## Three registers, and they are not interchangeable

This is the part worth arguing about, because the graphic carries a claim.
The coloured discs **are** DREAM's models. Used as wallpaper they would say
"family" on pages that are not about the family.

| Register | File | Means | Used on |
| --- | --- | --- | --- |
| Family | `assets/family.svg` | The DREAM models, GreenREFORM-EU among them | Home hero, About lineage |
| Lineage | inline SVG in `index.html` | MAKRO to Gr&oslash;nREFORM to GreenREFORM-EU, labelled | Home, "Where it comes from" |
| Quiet | `assets/constellation-quiet.svg` | Nothing. Page texture | Interior page heads |
| Grid | `.gridpaper` in CSS | Nothing. Squared paper | Page heads, hero, signup band, sitemap |

The quiet register is the same arrangement of discs drawn entirely in mist. It
introduces no sixth colour and makes no claim about the family.

The grid and the quiet discs fade out towards the bottom of the band they sit
in, and the band has no bottom rule. Because the band keeps the page
background colour, there is nothing left to mark where it ended: the graphic
simply runs out and the page continues. The signup band is the exception. It
has its own colour and its own rules top and bottom, so its edge is deliberate
and the grid stays even across it.

The five colours and the rule that green is never decoration carry over
unchanged from `../mockups`. The grid is mist, the quiet discs are mist, and
the only green on a page is still the model or a link.

## What the pages do differently

- **Home** opens with the family constellation beside the headline, and closes
 "Where it comes from" with a labelled lineage diagram. The lineage is the
 honest version of the claim: MAKRO, then Gr&oslash;nREFORM, then this model.
- **Interior pages** have a page head band on squared paper, with the quiet
 constellation fading in from the right.
- **Country teams** on Applications use the disc-and-type component from
 `brand-lab/boards/05c-dream-heritage-applications.html`: the disc is never
 modified, never re-coloured, and never has anything added to it. What a
 country needs to say is said in type beside it.
- **The signup band** and the **sitemap** sit on squared paper.

## Open questions this raises

1. **The green country pill.** Sheet 05c gives country teams a green-tinted
 pill. Sheet 05d says green means the model or a link, and a country name is
 neither. Both are Direction 05. One of them has to give.
2. **Quoting DREAM's colours.** The family graphic reproduces the DREAM,
 MAKRO, REFORM, SMILE and Gr&oslash;nREFORM disc colours. They are DREAM's,
 read off dreamgruppen.dk. Showing them on the GreenREFORM-EU site is a
 statement about the relationship between the models and needs DREAM's
 agreement, not just a designer's.
3. **How often the family may appear.** It is used twice here. More than that
 and it stops being a claim and becomes decoration.
4. **The disc at 44 px.** The country cards follow sheet 05c and use the full
 disc at 44 px, below the 56 px floor that sheet 05b sets. Either the floor
 moves or the cards use the initial, as the favicon does.

## Files

```
index.html               The model (home)
documentation.html       Documentation
user-guide.html          User guide
get-the-model.html       Get the model
applications.html        Applications
analysis-tsi-paper.html  One analysis record
news.html                News
about.html               About
sitemap.html             Sitemap diagram, not a site page
assets/site.css          Direction 05 theme, plus the graphic system
assets/family.svg        The connected discs, in the family colours
assets/constellation-quiet.svg  The same arrangement, in mist
assets/mark.svg          The model disc
assets/favicon.svg       The initial, for sizes below the floor
```

## Screenshots

`screenshots/` holds flat images for slides, email and print. Each is 3720 px
wide: the 1240 px page rendered at three times scale. Nine pages here, against
seven in `../mockups`, because About and the user guide now carry graphics
worth showing.

Regenerate as in [../mockups/README.md](../mockups/README.md). Page heights at
1240 px wide: sitemap 1191, home 2674, documentation 2198, get the model 1733,
applications 2921, news 1680, analysis 1832, about 2062, user guide 1632.

Type is Hind from Google Fonts, so the renderer needs a network connection or
the screenshots fall back to Segoe UI and stop matching the pages.
