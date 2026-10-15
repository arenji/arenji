// Highlights the section currently in view in the side menu (.page-toc).
(function () {
    var links = document.querySelectorAll('.page-toc a[href^="#"]');
    if (!links.length) return;

    var byId = {};
    var headings = [];
    links.forEach(function (a) {
        var id = a.getAttribute('href').slice(1);
        var h = document.getElementById(id);
        if (h) { byId[id] = a; headings.push(h); }
    });

    function setActive(id) {
        links.forEach(function (a) { a.classList.remove('is-active'); });
        if (byId[id]) byId[id].classList.add('is-active');
    }

    function update() {
        // The active section is the last heading that has scrolled above 30% of the viewport.
        var line = window.innerHeight * 0.3;
        var current = headings[0];
        headings.forEach(function (h) {
            if (h.getBoundingClientRect().top <= line) current = h;
        });
        // At the very bottom of the page, highlight the last section.
        if (window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 2) {
            current = headings[headings.length - 1];
        }
        if (current) setActive(current.id);
    }

    var ticking = false;
    window.addEventListener('scroll', function () {
        if (!ticking) {
            ticking = true;
            window.requestAnimationFrame(function () { update(); ticking = false; });
        }
    }, { passive: true });
    window.addEventListener('resize', update);
    update();
})();
