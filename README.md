# Ragnar Enger Juelsrud - Academic Website

A minimal, SEO-optimized academic website for deployment on GitHub Pages.

---

## 📁 Files Included

| File | Purpose |
|------|---------|
| `index.html` | Homepage with bio and contact |
| `research.html` | Research papers and publications |
| `teaching.html` | Course information |
| `style.css` | Styling |
| `sitemap.xml` | SEO: Helps search engines index your site |
| `robots.txt` | SEO: Instructions for search engine crawlers |

**You need to add:**
- `photo.jpg` - Your professional photo
- `cv.pdf` - Your CV/resume

---

## 🚀 Deployment to GitHub Pages

### Step 1: Create a GitHub account
Go to [github.com](https://github.com) and sign up (free)

### Step 2: Create a new repository
1. Click the **+** icon → **New repository**
2. Name it: `ragnarjuelsrud.github.io` (replace with your username)
3. Keep it **Public**
4. Click **Create repository**

### Step 3: Upload your files
1. Click **uploading an existing file**
2. Drag all the files (HTML, CSS, sitemap.xml, robots.txt, photo.jpg, cv.pdf)
3. Click **Commit changes**

### Step 4: Enable GitHub Pages
1. Go to **Settings** → **Pages**
2. Source: **Deploy from a branch**
3. Branch: **main** / **root**
4. Click **Save**

Your site will be live at `https://yourusername.github.io` within 2-5 minutes.

---

## 🔍 SEO Features Included

This website is optimized for search engines with:

### Meta Tags
- Title tags unique to each page
- Meta descriptions for search results snippets
- Keywords for relevant search queries
- Canonical URLs to prevent duplicate content

### Structured Data (JSON-LD)
- Person schema on homepage (helps Google understand who you are)
- ScholarlyArticle schema on research page (rich results for publications)
- Proper markup for academic profile

### Technical SEO
- Semantic HTML5 (`<header>`, `<main>`, `<article>`, `<section>`, `<footer>`)
- Proper heading hierarchy (H1 → H2 → H3)
- `sitemap.xml` for search engine crawling
- `robots.txt` with sitemap reference
- Mobile-responsive design
- Fast-loading fonts with `display=swap`
- Accessibility features (ARIA labels, focus states)

### Open Graph & Twitter Cards
- Social sharing previews for Facebook, LinkedIn, Twitter
- Profile photo appears when shared

---

## 🌐 Custom Domain Setup (Optional)

### Step 1: Buy a domain
Purchase from [Namecheap](https://namecheap.com) or [Google Domains](https://domains.google) (~$12/year)

Suggestions: `ragnarjuelsrud.com`, `ragnarjuelsrud.no`

### Step 2: Configure DNS
Add these records at your domain registrar:

| Type | Name | Value |
|------|------|-------|
| A | @ | 185.199.108.153 |
| A | @ | 185.199.109.153 |
| A | @ | 185.199.110.153 |
| A | @ | 185.199.111.153 |
| CNAME | www | yourusername.github.io |

### Step 3: Update GitHub
1. In repository **Settings** → **Pages**
2. Enter your custom domain
3. Check **Enforce HTTPS**

### Step 4: Update the website files
After setting up your domain, update these URLs in all HTML files:
- Change `https://ragnarjuelsrud.com` to your actual domain
- Update `sitemap.xml` with your domain
- Update `robots.txt` with your domain

---

## 📝 How to Update Content

### Adding a new paper
In `research.html`, add inside the appropriate section:

```html
<article class="paper">
    <h3 class="paper-title"><a href="PAPER_URL">Paper Title</a></h3>
    <p class="paper-authors">with Coauthor Name</p>
    <p class="paper-status"><strong>Journal Name</strong>, Year</p>
</article>
```

### Adding a course
In `teaching.html`, add:

```html
<article class="course">
    <h3 class="course-title">ECON4310 – Course Name</h3>
    <p class="course-info">Master's level, Spring 2025</p>
    <p class="course-description">Brief description of the course.</p>
</article>
```

### Updating meta descriptions
When you add significant content, update the `<meta name="description">` tag in the `<head>` of each page to reflect the new content.

---

## 🔧 Post-Launch SEO Checklist

After your site is live:

1. **Submit to Google Search Console**
   - Go to [search.google.com/search-console](https://search.google.com/search-console)
   - Add your property (domain)
   - Submit your sitemap: `https://yourdomain.com/sitemap.xml`

2. **Submit to Bing Webmaster Tools**
   - Go to [bing.com/webmasters](https://www.bing.com/webmasters)
   - Add your site and submit sitemap

3. **Add your website URL to:**
   - Your University of Oslo staff page
   - Google Scholar profile
   - ORCID profile
   - RePEc/IDEAS author page
   - LinkedIn profile
   - Any coauthor papers that link to you

4. **Monitor performance**
   - Check Google Search Console weekly for the first month
   - Look for crawl errors and fix them
   - Monitor which keywords bring traffic

---

## 🎨 Customization

### Change colors
Edit the `:root` section in `style.css`:

```css
--color-accent: #2c5282;  /* Links */
--color-bg: #fafaf9;      /* Background */
--color-text: #1a1a1a;    /* Main text */
```

### Change fonts
Update the Google Fonts link in each HTML file's `<head>`.

---

## ❓ Need Help?

Common issues:
- **Site not loading**: Wait 2-5 minutes after deployment
- **Custom domain not working**: DNS can take up to 48 hours (usually 30 min)
- **Photo not showing**: Ensure it's named exactly `photo.jpg`
- **Search Console errors**: Check for broken links or missing files

Good luck with your new position at UiO! 🎓
