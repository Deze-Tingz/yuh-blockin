<?php
/**
 * Template Name: YuhBlockin Home
 * Description: Premium landing page for YuhBlockin app
 */

// Set premium page title before header loads
add_filter( 'pre_get_document_title', function() {
	return 'YuhBlockin — Move with Respect';
}, 999 );

// Add favicon
add_action( 'wp_head', function() {
	$favicon = get_template_directory_uri() . '/assets/images/favicon.png';
	echo '<link rel="icon" type="image/png" sizes="192x192" href="' . esc_url( $favicon ) . '">' . "\n";
	echo '<link rel="apple-touch-icon" sizes="180x180" href="' . esc_url( $favicon ) . '">' . "\n";
}, 1 );

get_header();
?>

<div class="yb-landing">

  <!-- Header -->
  <header class="yb-header">
    <div class="yb-container">
      <div class="yb-header__inner">
        <nav class="yb-header__nav" aria-label="Main navigation">
          <a href="#how-it-works" class="yb-header__nav-link">How it works</a>
          <a href="#why-it-matters" class="yb-header__nav-link">Why it matters</a>
          <a href="#for-properties" class="yb-header__nav-link">For properties</a>
          <a href="#faq" class="yb-header__nav-link">FAQ</a>
        </nav>

        <a href="#get-app" class="yb-btn yb-btn--primary yb-btn--sm yb-header__cta">
          <span>Get the App</span>
        </a>
      </div>
    </div>
  </header>

  <!-- Hero Section -->
  <section class="yb-hero">
    <!-- SVG Background Pattern -->
    <div class="yb-hero__bg-pattern" aria-hidden="true"></div>

    <!-- Scattered Decorative Icons -->
    <div class="yb-hero__icons" aria-hidden="true">
      <!-- Car top-left -->
      <svg class="yb-icon yb-icon--car-1" viewBox="0 0 80 80" fill="none">
        <rect x="10" y="35" width="60" height="24" rx="5" fill="#21819B"/>
        <path d="M20 35V25C20 22 23 17 30 17H50C57 17 60 22 60 25V35" stroke="#21819B" stroke-width="4" fill="none"/>
        <circle cx="24" cy="52" r="7" fill="#4dd4ff"/>
        <circle cx="56" cy="52" r="7" fill="#4dd4ff"/>
      </svg>
      <!-- Bell top-right -->
      <svg class="yb-icon yb-icon--bell" viewBox="0 0 64 64" fill="none">
        <path d="M32 6C32 6 16 8 16 28V40L8 50H56L48 40V28C48 8 32 6 32 6Z" fill="#DE5E59"/>
        <circle cx="32" cy="56" r="6" fill="#DE5E59"/>
      </svg>
      <!-- Parking sign left-center -->
      <svg class="yb-icon yb-icon--parking" viewBox="0 0 64 64" fill="none">
        <rect x="8" y="8" width="48" height="48" rx="8" fill="#21819B"/>
        <path d="M24 44V20H36C42 20 46 24 46 30C46 36 42 40 36 40H32V44H24Z" fill="#fff"/>
        <path d="M32 26V34H36C38.5 34 40 32.5 40 30C40 27.5 38.5 26 36 26H32Z" fill="#21819B"/>
      </svg>
      <!-- Traffic light right-center -->
      <svg class="yb-icon yb-icon--light" viewBox="0 0 64 80" fill="none">
        <rect x="16" y="4" width="32" height="60" rx="6" fill="#3A424B"/>
        <circle cx="32" cy="18" r="8" fill="#DE5E59"/>
        <circle cx="32" cy="36" r="8" fill="#f0c54d" opacity="0.5"/>
        <circle cx="32" cy="54" r="8" fill="#4ade80" opacity="0.5"/>
      </svg>
      <!-- Keys bottom-left -->
      <svg class="yb-icon yb-icon--keys" viewBox="0 0 64 64" fill="none">
        <circle cx="20" cy="20" r="14" stroke="#21819B" stroke-width="4" fill="none"/>
        <circle cx="20" cy="20" r="6" fill="#21819B"/>
        <rect x="30" y="17" width="28" height="6" rx="2" fill="#21819B"/>
        <rect x="48" y="23" width="4" height="10" rx="1" fill="#21819B"/>
        <rect x="40" y="23" width="4" height="8" rx="1" fill="#21819B"/>
      </svg>
      <!-- Car 2 bottom-right -->
      <svg class="yb-icon yb-icon--car-2" viewBox="0 0 80 80" fill="none">
        <rect x="10" y="35" width="60" height="24" rx="5" fill="#DE5E59"/>
        <path d="M20 35V25C20 22 23 17 30 17H50C57 17 60 22 60 25V35" stroke="#DE5E59" stroke-width="4" fill="none"/>
        <circle cx="24" cy="52" r="7" fill="#fff"/>
        <circle cx="56" cy="52" r="7" fill="#fff"/>
      </svg>
    </div>

    <!-- Bottom Wave -->
    <div class="yb-hero__wave" aria-hidden="true">
      <svg viewBox="0 0 1440 120" preserveAspectRatio="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M0,60 C360,120 1080,0 1440,60 L1440,120 L0,120 Z" fill="#F7F8FA"/>
      </svg>
    </div>

    <div class="yb-container">
      <div class="yb-hero__inner">
        <div class="yb-hero__content">
          <h1 class="yb-hero__headline">Don't argue in the lot.<br>Just send a respectful ping.</h1>
          <p class="yb-hero__subcopy">YuhBlockin helps drivers resolve blocked parking quietly and quickly—right from their phones.</p>
          <div class="yb-hero__actions">
            <a href="#get-app" class="yb-btn yb-btn--primary yb-btn--lg">
              <span>Get YuhBlockin</span>
            </a>
            <a href="#how-it-works" class="yb-btn yb-btn--outline yb-btn--lg">
              <span>See how it works</span>
            </a>
          </div>

          <!-- Waitlist Section -->
          <div class="yb-waitlist">
            <form class="yb-waitlist__form" id="waitlist-form">
              <div class="yb-waitlist__input-group">
                <input type="email" class="yb-waitlist__input" id="waitlist-email" placeholder="Enter your email" required>
                <p class="yb-waitlist__counter"><span id="waitlist-count">0</span> joined</p>
              </div>
              <button type="submit" class="yb-btn yb-btn--primary" id="join-waitlist-btn">
                <span>Join Waitlist</span>
              </button>
            </form>
          </div>
        </div>

        <div class="yb-hero__visual">
          <img
            src="<?php echo esc_url(get_site_url() . '/wp-content/uploads/2026/01/premium-user-splash.png'); ?>"
            alt="YuhBlockin - Move with respect"
            class="yb-hero__brand-card"
          >
        </div>
      </div>
    </div>
  </section>

  <!-- How It Works Section -->
  <section id="how-it-works" class="yb-how">
    <div class="yb-container">
      <header class="yb-section-header">
        <h2 class="yb-section-header__title">How it works</h2>
        <p class="yb-section-header__subtitle" style="text-align: center;">Three simple steps to resolve blocked parking without the drama.</p>
      </header>

      <div class="yb-how__grid">
        <article class="yb-step-card">
          <div class="yb-step-card__number">1</div>
          <h3 class="yb-step-card__title">Register your vehicle</h3>
          <p class="yb-step-card__text">Sign up and receive a unique code. Display it on your dashboard so others can reach you.</p>
        </article>

        <article class="yb-step-card">
          <div class="yb-step-card__number">2</div>
          <h3 class="yb-step-card__title">Get a respectful alert</h3>
          <p class="yb-step-card__text">When someone's blocked, they enter your code. You get a private, polite notification.</p>
        </article>

        <article class="yb-step-card">
          <div class="yb-step-card__number">3</div>
          <h3 class="yb-step-card__title">Move and done</h3>
          <p class="yb-step-card__text">You move your car, they're on their way. No drama, no confrontation, no stress.</p>
        </article>
      </div>
    </div>
  </section>

  <!-- Why It Matters Section -->
  <section id="why-it-matters" class="yb-why">
    <div class="yb-container">
      <header class="yb-section-header">
        <h2 class="yb-section-header__title">Why it matters</h2>
      </header>

      <div class="yb-why__grid">
        <article class="yb-benefit">
          <div class="yb-benefit__icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
            </svg>
          </div>
          <h3 class="yb-benefit__title">Less conflict</h3>
          <p class="yb-benefit__text">No honking, no yelling, no awkward confrontations in public spaces.</p>
        </article>

        <article class="yb-benefit">
          <div class="yb-benefit__icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
              <circle cx="9" cy="7" r="4"/>
              <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
              <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
            </svg>
          </div>
          <h3 class="yb-benefit__title">Safer spaces</h3>
          <p class="yb-benefit__text">Remove tension from parking lots. Everyone stays calm and moves on.</p>
        </article>

        <article class="yb-benefit">
          <div class="yb-benefit__icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
              <polyline points="22 4 12 14.01 9 11.01"/>
            </svg>
          </div>
          <h3 class="yb-benefit__title">Respect built in</h3>
          <p class="yb-benefit__text">The system encourages courtesy. Quick, polite communication by design.</p>
        </article>

        <article class="yb-benefit">
          <div class="yb-benefit__icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="12" cy="12" r="10"/>
              <polyline points="12 6 12 12 16 14"/>
            </svg>
          </div>
          <h3 class="yb-benefit__title">Faster resolution</h3>
          <p class="yb-benefit__text">Get unblocked in minutes instead of waiting around or hunting someone down.</p>
        </article>
      </div>
    </div>
  </section>

  <!-- For Properties Section -->
  <section id="for-properties" class="yb-properties">
    <div class="yb-container">
      <div class="yb-properties__inner">
        <div class="yb-properties__content">
          <span class="yb-properties__label">For Properties</span>
          <h2 class="yb-properties__title">Give your parking areas a better way to communicate</h2>
          <p class="yb-properties__text">Whether you manage a shopping center, office building, or residential complex—YuhBlockin offers a modern alternative to paper notes and PA announcements.</p>
          <ul class="yb-properties__list">
            <li>Digital signage templates ready to deploy</li>
            <li>Anonymous alerts reduce parking confrontations</li>
            <li>No personal phone numbers posted on walls</li>
          </ul>
          <a href="#contact" class="yb-btn yb-btn--primary">
            <span>Talk to us about your property</span>
          </a>
        </div>

        <div class="yb-properties__visual">
          <div class="yb-stat-card">
            <p class="yb-stat-card__number">87%</p>
            <p class="yb-stat-card__label">of blocked situations resolved within 3 minutes</p>
          </div>
        </div>
      </div>
    </div>
  </section>

  <!-- FAQ Section -->
  <section id="faq" class="yb-faq">
    <div class="yb-container">
      <header class="yb-section-header">
        <h2 class="yb-section-header__title">Common questions</h2>
      </header>

      <div class="yb-faq__list">
        <div class="yb-accordion" data-open="false">
          <button class="yb-accordion__trigger" type="button">
            <span>How does YuhBlockin protect my privacy?</span>
            <span class="yb-accordion__icon" aria-hidden="true">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="6 9 12 15 18 9"/>
              </svg>
            </span>
          </button>
          <div class="yb-accordion__content" id="faq-1">
            <p class="yb-accordion__text">Your vehicle plate is converted to a secure hash that even we cannot reverse. Notifications are anonymous and one-way. The person alerting you cannot see your personal details, and you cannot see theirs.</p>
          </div>
        </div>

        <div class="yb-accordion" data-open="false">
          <button class="yb-accordion__trigger" type="button">
            <span>What notifications will I receive?</span>
            <span class="yb-accordion__icon" aria-hidden="true">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="6 9 12 15 18 9"/>
              </svg>
            </span>
          </button>
          <div class="yb-accordion__content" id="faq-2">
            <p class="yb-accordion__text">You'll receive a single push notification when someone reports that you're blocking them. That's it. No marketing messages, no reminders, no spam.</p>
          </div>
        </div>

        <div class="yb-accordion" data-open="false">
          <button class="yb-accordion__trigger" type="button">
            <span>Where is YuhBlockin available?</span>
            <span class="yb-accordion__icon" aria-hidden="true">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="6 9 12 15 18 9"/>
              </svg>
            </span>
          </button>
          <div class="yb-accordion__content" id="faq-3">
            <p class="yb-accordion__text">We're starting in the British Virgin Islands via Apple TestFlight. Android and broader availability will follow based on demand and readiness.</p>
          </div>
        </div>

        <div class="yb-accordion" data-open="false">
          <button class="yb-accordion__trigger" type="button">
            <span>Is there a cost?</span>
            <span class="yb-accordion__icon" aria-hidden="true">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="6 9 12 15 18 9"/>
              </svg>
            </span>
          </button>
          <div class="yb-accordion__content" id="faq-4">
            <p class="yb-accordion__text">The core service is free during early access. Our goal is to build useful public infrastructure, not extract value from a captive audience.</p>
          </div>
        </div>
      </div>
    </div>
  </section>

  <!-- Final CTA Section -->
  <section id="get-app" class="yb-cta">
    <!-- Scattered Decorative Icons -->
    <div class="yb-cta__icons" aria-hidden="true">
      <!-- Car -->
      <svg class="yb-cta-icon yb-cta-icon--car" viewBox="0 0 80 80" fill="none">
        <rect x="10" y="35" width="60" height="24" rx="5" fill="#21819B"/>
        <path d="M20 35V25C20 22 23 17 30 17H50C57 17 60 22 60 25V35" stroke="#21819B" stroke-width="4" fill="none"/>
        <circle cx="24" cy="52" r="7" fill="#4dd4ff"/>
        <circle cx="56" cy="52" r="7" fill="#4dd4ff"/>
      </svg>
      <!-- Bell -->
      <svg class="yb-cta-icon yb-cta-icon--bell" viewBox="0 0 64 64" fill="none">
        <path d="M32 6C32 6 16 8 16 28V40L8 50H56L48 40V28C48 8 32 6 32 6Z" fill="#DE5E59"/>
        <circle cx="32" cy="56" r="6" fill="#DE5E59"/>
      </svg>
      <!-- Parking -->
      <svg class="yb-cta-icon yb-cta-icon--parking" viewBox="0 0 64 64" fill="none">
        <rect x="8" y="8" width="48" height="48" rx="8" fill="#21819B"/>
        <path d="M24 44V20H36C42 20 46 24 46 30C46 36 42 40 36 40H32V44H24Z" fill="#fff"/>
        <path d="M32 26V34H36C38.5 34 40 32.5 40 30C40 27.5 38.5 26 36 26H32Z" fill="#21819B"/>
      </svg>
      <!-- Keys -->
      <svg class="yb-cta-icon yb-cta-icon--keys" viewBox="0 0 64 64" fill="none">
        <circle cx="20" cy="20" r="14" stroke="#21819B" stroke-width="4" fill="none"/>
        <circle cx="20" cy="20" r="6" fill="#21819B"/>
        <rect x="30" y="17" width="28" height="6" rx="2" fill="#21819B"/>
        <rect x="48" y="23" width="4" height="10" rx="1" fill="#21819B"/>
        <rect x="40" y="23" width="4" height="8" rx="1" fill="#21819B"/>
      </svg>
    </div>

    <div class="yb-container">
      <div class="yb-cta__inner">
        <h2 class="yb-cta__title">Move with respect.</h2>
        <p class="yb-cta__text">Join the community making parking less stressful in the BVI.</p>
        <a href="#" class="yb-btn yb-btn--primary yb-btn--lg yb-btn--on-dark">
          <span>Get YuhBlockin</span>
        </a>
      </div>
    </div>
  </section>

  <!-- Footer -->
  <footer class="yb-footer">
    <div class="yb-container">
      <div class="yb-footer__grid">
        <div class="yb-footer__column">
          <h4 class="yb-footer__heading">Product</h4>
          <ul class="yb-footer__list">
            <li><a href="#how-it-works" class="yb-footer__link">How it works</a></li>
            <li><a href="#" class="yb-footer__link">Download</a></li>
            <li><a href="#" class="yb-footer__link">For drivers</a></li>
          </ul>
        </div>

        <div class="yb-footer__column">
          <h4 class="yb-footer__heading">For Sites</h4>
          <ul class="yb-footer__list">
            <li><a href="#for-properties" class="yb-footer__link">Property managers</a></li>
            <li><a href="#" class="yb-footer__link">Signage templates</a></li>
            <li><a href="#contact" class="yb-footer__link">Contact sales</a></li>
          </ul>
        </div>

        <div class="yb-footer__column">
          <h4 class="yb-footer__heading">Legal</h4>
          <ul class="yb-footer__list">
            <li><a href="#" class="yb-footer__link">Privacy policy</a></li>
            <li><a href="#" class="yb-footer__link">Terms of service</a></li>
          </ul>
        </div>

        <div class="yb-footer__column">
          <h4 class="yb-footer__heading">Contact</h4>
          <ul class="yb-footer__list">
            <li><a href="mailto:dev@dezetingz.ai" class="yb-footer__link">dev@dezetingz.ai</a></li>
            <li><span class="yb-footer__text">Road Town, Tortola</span></li>
            <li><span class="yb-footer__text">British Virgin Islands</span></li>
          </ul>
        </div>
      </div>

      <div class="yb-footer__bottom">
        <p class="yb-footer__copyright">YuhBlockin</p>
        <p class="yb-footer__tagline">Built for the BVI.</p>
        <p class="yb-footer__legal">2026 &copy; DezeTingz</p>
      </div>
    </div>
  </footer>

</div>

<?php get_footer(); ?>
