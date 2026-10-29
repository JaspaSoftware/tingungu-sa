/* ===================================================================
 * Tingungu Modern JS script
 * Controls mobile navigation, scroll actions, and form events.
 * =================================================================== */

document.addEventListener('DOMContentLoaded', function() {
  
  // Mobile menu toggle
  const menuToggle = document.getElementById('menuToggle');
  const navLinks = document.getElementById('navLinks');
  
  if (menuToggle && navLinks) {
    menuToggle.addEventListener('click', function(e) {
      e.stopPropagation();
      navLinks.classList.toggle('active');
      const icon = menuToggle.textContent;
      menuToggle.textContent = icon === '☰' ? '✕' : '☰';
    });
    
    // Close mobile menu when clicking outside
    document.addEventListener('click', function(e) {
      if (!navLinks.contains(e.target) && e.target !== menuToggle) {
        navLinks.classList.remove('active');
        menuToggle.textContent = '☰';
      }
    });
  }

  // Scroll effect on Navbar
  const navbar = document.getElementById('navbar');
  window.addEventListener('scroll', function() {
    if (window.scrollY > 50) {
      navbar.classList.add('scrolled');
    } else {
      navbar.classList.remove('scrolled');
    }
  });

  // Footer Year Automatic Update
  const currentYear = new Date().getFullYear();
  document.querySelectorAll('.js-current-year').forEach(function(el) {
    el.textContent = currentYear;
  });

  // Contact Form Submission Handling
  const contactForm = document.getElementById('contactForm');
  if (contactForm) {
    contactForm.addEventListener('submit', async function(e) {
      e.preventDefault();

      const submitBtn = contactForm.querySelector('input[type="submit"]');
      if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.value = 'Sending Message...';
      }

      const name = document.getElementById('cName')?.value.trim() || '';
      const email = document.getElementById('cEmail')?.value.trim() || '';
      const website = document.getElementById('cWebsite')?.value.trim() || '';
      const message = document.getElementById('cMessage')?.value.trim() || '';

      if (!name || !email || !message) {
        alert('Please fill out all required fields.');
        if (submitBtn) {
          submitBtn.disabled = false;
          submitBtn.value = 'Send Message';
        }
        return;
      }

      const apiBase = (
        window.TINGUNGU_API_BASE ||
        (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
          ? 'http://localhost:5000'
          : 'https://tingungu-api.azurewebsites.net')
      ).replace(/\/$/, '');
      const status = document.getElementById('contactFormStatus');

      try {
        const response = await fetch(`${apiBase}/api/contact`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ name, email, website, message }),
        });

        const result = await response.json().catch(() => ({}));

        if (!response.ok) {
          throw new Error(result.error || 'Unable to send your message right now.');
        }

        if (status) {
          status.textContent = result.message || `Thank you, ${name}. Your message has been received.`;
          status.className = 'form-status success';
        }
        contactForm.reset();
      } catch (error) {
        console.error('Contact form submission failed:', error);
        if (status) {
          status.textContent = error.message || 'Something went wrong while sending your message. Please try again later.';
          status.className = 'form-status error';
        }
      } finally {
        if (submitBtn) {
          submitBtn.disabled = false;
          submitBtn.value = 'Send Message';
        }
      }
    });
  }

});
