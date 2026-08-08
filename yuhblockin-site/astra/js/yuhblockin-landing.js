/**
 * YuhBlockin Landing Page Scripts
 * Accessible accordion functionality
 */

(function() {
  'use strict';

  // Supabase config
  const SUPABASE_URL = 'https://oazxwglbvzgpehsckmfb.supabase.co';
  const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9henh3Z2xidnpncGVoc2NrbWZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMxNzkzMjEsImV4cCI6MjA3ODc1NTMyMX0.Ia6ccZ1zp4r1mi5mgvQk9wfK5MGp0S3TDhyWngz8Z54';

  /**
   * Initialize accordion functionality
   */
  function initAccordion() {
    const accordions = document.querySelectorAll('.yb-accordion');

    accordions.forEach(function(accordion) {
      const trigger = accordion.querySelector('.yb-accordion__trigger');
      const content = accordion.querySelector('.yb-accordion__content');
      const contentId = content.id;

      // Set initial ARIA attributes
      trigger.setAttribute('aria-expanded', 'false');
      trigger.setAttribute('aria-controls', contentId);
      content.setAttribute('aria-hidden', 'true');

      // Click handler
      trigger.addEventListener('click', function() {
        toggleAccordion(accordion, trigger, content);
      });

      // Keyboard handler
      trigger.addEventListener('keydown', function(e) {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          toggleAccordion(accordion, trigger, content);
        }
      });
    });
  }

  /**
   * Toggle accordion open/closed
   */
  function toggleAccordion(accordion, trigger, content) {
    const isOpen = accordion.getAttribute('data-open') === 'true';
    const newState = !isOpen;

    accordion.setAttribute('data-open', newState);
    trigger.setAttribute('aria-expanded', newState);
    content.setAttribute('aria-hidden', !newState);
  }

  /**
   * Smooth scroll for anchor links
   */
  function initSmoothScroll() {
    const links = document.querySelectorAll('a[href^="#"]');

    links.forEach(function(link) {
      link.addEventListener('click', function(e) {
        const targetId = this.getAttribute('href');
        if (targetId === '#') return;

        const target = document.querySelector(targetId);
        if (target) {
          e.preventDefault();

          // Check for reduced motion preference
          const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

          target.scrollIntoView({
            behavior: prefersReducedMotion ? 'auto' : 'smooth',
            block: 'start'
          });

          // Update focus for accessibility
          target.setAttribute('tabindex', '-1');
          target.focus({ preventScroll: true });
        }
      });
    });
  }

  /**
   * Initialize waitlist form
   */
  function initWaitlistForm() {
    const form = document.getElementById('waitlist-form');
    const emailInput = document.getElementById('waitlist-email');
    const submitBtn = document.getElementById('join-waitlist-btn');
    const countDisplay = document.getElementById('waitlist-count');

    if (!form) return;

    // Fetch current waitlist count on load
    fetchWaitlistCount(countDisplay);

    // Handle form submission
    form.addEventListener('submit', async function(e) {
      e.preventDefault();
      const email = emailInput.value.trim();

      if (email) {
        submitBtn.disabled = true;
        submitBtn.innerHTML = '<span>Joining...</span>';

        try {
          const response = await fetch(SUPABASE_URL + '/rest/v1/waitlist', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'apikey': SUPABASE_ANON_KEY,
              'Authorization': 'Bearer ' + SUPABASE_ANON_KEY,
              'Prefer': 'return=minimal'
            },
            body: JSON.stringify({ email: email })
          });

          if (response.ok || response.status === 201 || response.status === 409) {
            // Update counter
            if (response.status !== 409) {
              const currentCount = parseInt(countDisplay.textContent) || 0;
              countDisplay.textContent = currentCount + 1;
            }

            // Show success
            form.innerHTML = '<div class="yb-waitlist__success"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg><span>You\'re on the list!</span></div>';
          } else {
            throw new Error('Failed');
          }
        } catch (error) {
          console.error('Waitlist error:', error);
          submitBtn.disabled = false;
          submitBtn.innerHTML = '<span>Try Again</span>';
        }
      }
    });
  }

  /**
   * Fetch current waitlist count from Supabase
   */
  async function fetchWaitlistCount(countDisplay) {
    try {
      const response = await fetch(SUPABASE_URL + '/rest/v1/waitlist?select=id', {
        method: 'GET',
        headers: {
          'apikey': SUPABASE_ANON_KEY,
          'Authorization': 'Bearer ' + SUPABASE_ANON_KEY
        }
      });

      if (response.ok) {
        const data = await response.json();
        countDisplay.textContent = data.length || 0;
      }
    } catch (error) {
      console.error('Failed to fetch waitlist count:', error);
    }
  }

  /**
   * Initialize on DOM ready
   */
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
      initAccordion();
      initSmoothScroll();
      initWaitlistForm();
    });
  } else {
    initAccordion();
    initSmoothScroll();
    initWaitlistForm();
  }

})();
