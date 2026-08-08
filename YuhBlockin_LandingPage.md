\# CLAUDE CODE — META PROMPT (YuhBlockin Premium Website)

You are Claude Code acting as a senior product designer + front-end engineer. Build a hyper-premium marketing site using ONLY the visual language from the provided reference images (teal + coral + dark slate, calm premium depth, clean sans-serif). Do NOT reuse any prior “government” concepts. No old artifacts.



\## GOAL

Create a production-ready, responsive landing website for the YuhBlockin mobile app. Deliver:

1\) Clean, modern UI (desktop + mobile) with premium spacing and restrained motion

2\) Reusable components and a small design system (tokens)

3\) Accessible, fast, SEO-friendly build

4\) No stock photos. Use brand-led geometry, device mock frames, and minimal iconography.



\## STACK (choose one and commit)

\- Preferred: Next.js (App Router) + TypeScript + Tailwind CSS

\- Alt: Vite + React + TypeScript + Tailwind CSS

Use lucide-react icons only. No heavy UI libraries. No external image dependencies.



\## REFERENCE-DRIVEN BRAND RULES (MANDATORY)

Use these brand colors (derived from refs):

\- Teal (primary): #21819B

\- Coral (accent): #DE5E59

\- Slate (dark surface): #3A424B

\- Off-white (background): #F7F8FA

\- Border grey: #D3D7DE

\- Text grey: #4D5660



Usage rules:

\- Teal = primary CTAs, links, key UI surfaces

\- Coral = very restrained: small highlights, alert indicator, badge, emphasis only

\- Slate = hero/background sections + footer

\- No loud gradients; if used, ultra-subtle tonal shift only

\- Shadows are soft + premium (material feel), not “glowy neon”

\- Typography is clean sans-serif only



Typography:

\- Use system font stack or install Inter (body) + a geometric sans for headings (e.g., Poppins). Keep it minimal.

\- Headings: confident, geometric, bold

\- Body: calm, readable, neutral



Tone:

\- Calm. Respectful. Utility-forward. No hype marketing language. No emojis.



\## SITE STRUCTURE (REQUIRED SECTIONS)

\### 1) Header / Nav

\- Left: YuhBlockin logo lockup (use inline SVG placeholder if needed)

\- Right: How it works, Why it matters, For properties, FAQ

\- CTA button: “Get YuhBlockin”



\### 2) Hero

\- Background: Slate surface with subtle texture/gradient (very restrained)

\- Headline: “Don’t argue in the lot. Just send a respectful ping.”

\- Subcopy: “YuhBlockin helps drivers resolve blocked parking quietly and quickly—right from their phones.”

\- CTAs: Primary “Get YuhBlockin” (teal), Secondary “See how it works” (outline)

\- Right: premium device mock (vector/HTML) showing a simple in-app message UI (no car imagery; use chat bubbles + “You’re blocking me” + “On my way — give me 2 mins”)



\### 3) How it works (3 steps)

Cards with minimal icons:

1\. Register your vehicle

2\. Get a respectful alert

3\. Move and done

Cards on off-white with soft shadow and teal accents.



\### 4) Why it matters

3–4 benefit tiles:

\- Less conflict

\- Safer spaces

\- Respect built in

\- Faster resolution

Use subtle coral accent only as small dots/badges.



\### 5) For properties / businesses

A clean feature panel:

\- “Give your car parks a better way to communicate”

Bullets:

\- Digital signage templates

\- QR onboarding

\- No personal phone numbers posted on walls/windshields

CTA: “Talk to us about your property”



\### 6) Product preview strip

Dark slate band with 3 device frames (HTML/CSS) showing:

\- Register screen

\- Alert received

\- Quick reply options

Keep text crisp. No placeholder gibberish.



\### 7) FAQ

Accordion component (accessible)

At least 5 questions (privacy, notifications, misuse reporting, availability, costs)



\### 8) Final CTA + Footer

CTA: “Move with respect.”

Footer: Product, For Sites, Legal (Privacy, Terms), Contact.



\## COMPONENTS (MUST IMPLEMENT)

\- Button (primary/secondary)

\- Card

\- Badge (coral/teal)

\- Accordion

\- Section container

\- Device mock component (reusable)

\- Simple icon system (lucide)



\## DESIGN SYSTEM TOKENS (EXPORT)

Create a `tokens.ts` (or `theme.ts`) with:

\- colors

\- spacing scale

\- radius

\- shadow presets

\- typography sizes



\## ACCESSIBILITY + QUALITY

\- Semantic HTML, proper headings order

\- 4.5:1 contrast where applicable

\- Keyboard accessible nav + accordion

\- Lighthouse-minded: optimize images (use SVG/HTML for mock devices)

\- Motion: subtle (opacity/translate), reduced-motion support



\## OUTPUT REQUIREMENTS

\- Generate the full project scaffold with all files.

\- Include `README.md` with:

&nbsp; - how to run

&nbsp; - how to deploy

&nbsp; - where to swap logo SVG

\- Provide clean, final code only. No long explanations.



\## HARD CONSTRAINTS

\- No car icons, parking signs, or literal car visuals.

\- No old “government grade” styling—follow the provided brand references only.

\- No external image URLs.

\- No trendy neon gradients, no playful shapes.



\## START NOW

1\) Create the folder structure

2\) Add Tailwind setup

3\) Build the page with components

4\) Verify responsive layout

5\) Ensure text matches the tone rules



