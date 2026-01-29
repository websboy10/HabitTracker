import './App.css'
import { BarChart3, Bell, Instagram, Target, Twitter } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'

const LEGAL_SECTIONS = {
  privacy: 'privacy',
  terms: 'terms',
}

function App() {
  const [legalSection, setLegalSection] = useState(null)

  useEffect(() => {
    const params = new URLSearchParams(window.location.search)
    const section = params.get('legal')
    if (section && LEGAL_SECTIONS[section]) {
      setLegalSection(section)
    }
  }, [])

  if (legalSection) {
    return <LegalPage initialSection={legalSection} onClose={() => setLegalSection(null)} />
  }

  return <LandingPage onOpenLegal={setLegalSection} />
}

function LandingPage({ onOpenLegal }) {
  return (
    <div className="page">
      <header className="header">
        <div className="floating-header">
          <img className="logo-icon" src="/app-icon.png" alt="N01 logo" />
          <span className="logo-text">N01</span>
        </div>
      </header>

      <main className="hero-section">
        <div className="hero-content">
          <h1 className="hero-title reveal">Build Better Habits<br />Transform Your Life</h1>
          <p className="hero-subtitle reveal">
            Track your daily goals, measure your progress, and stay consistent with the habit tracker designed to help you become
            your best self.
          </p>
          <div className="cta-row hero-cta reveal">
            <div className="cta-primary">
              <img className="app-store-icon" src="/appstore-badge.jpg" alt="App Store" />
              <div className="cta-text">
                <span>Download on the</span>
                <strong>App Store</strong>
              </div>
            </div>
          </div>
        </div>

        <div className="phones-section">
          <img className="phones-mockup reveal" src="/phones-mockup.png" alt="Habit Tracker app screens" />
        </div>
      </main>

      <section className="features-section">
        <div className="features-header reveal">
          <span className="badge">FEATURES</span>
          <h2>Everything You Need to<br />Build Lasting Habits</h2>
          <p>Powerful features designed to help you stay consistent and achieve your goals</p>
        </div>
        <div className="features-grid">
          <div className="feature-card reveal">
            <div className="feature-icon">
              <Target size={28} />
            </div>
            <h3>Daily Goal Tracking</h3>
            <p>
              Set daily, weekly, or monthly goals and track your progress with intuitive checkboxes. Never miss a habit again.
            </p>
          </div>
          <div className="feature-card reveal">
            <div className="feature-icon">
              <BarChart3 size={28} />
            </div>
            <h3>Progress Analytics</h3>
            <p>Visualize your consistency with detailed stats, streaks, and completion rates. See how far you've come.</p>
          </div>
          <div className="feature-card reveal">
            <div className="feature-icon">
              <Bell size={28} />
            </div>
            <h3>Smart Reminders</h3>
            <p>Get timely notifications to keep you on track. Customize reminder times for each individual habit.</p>
          </div>
        </div>
      </section>

      <section className="cta-section">
        <div className="cta-card reveal">
          <h2>Start Building Better<br />Habits Today</h2>
          <p>Join the NO.1 club and become NO.1.<br />Download now and take the first step.</p>
          <div className="cta-primary">
            <img className="app-store-icon" src="/appstore-badge.jpg" alt="App Store" />
            <div className="cta-text">
              <span>Download on the</span>
              <strong>App Store</strong>
            </div>
          </div>
        </div>
      </section>

      <footer className="footer">
        <div className="footer-top reveal">
          <div className="footer-left">
            <img className="footer-logo" src="/app-icon.png" alt="N01 logo" />
            <span>N01</span>
          </div>
          <div className="footer-links">
            <button className="footer-link" type="button" onClick={() => onOpenLegal(LEGAL_SECTIONS.privacy)}>
              Privacy Policy
            </button>
            <button className="footer-link" type="button" onClick={() => onOpenLegal(LEGAL_SECTIONS.terms)}>
              Terms of Service
            </button>
            <span>Contact</span>
          </div>
        </div>
        <div className="footer-divider" />
        <div className="footer-bottom reveal">
          <span className="footer-copy">© 2026 N01. All rights reserved.</span>
          <div className="socials">
            <span className="social">
              <Twitter size={18} />
            </span>
            <span className="social">
              <Instagram size={18} />
            </span>
          </div>
        </div>
      </footer>
    </div>
  )
}

function LegalPage({ initialSection, onClose }) {
  const [activeSection, setActiveSection] = useState(initialSection)
  const privacyRef = useRef(null)
  const termsRef = useRef(null)

  useEffect(() => {
    setActiveSection(initialSection)
  }, [initialSection])

  useEffect(() => {
    const target = activeSection === LEGAL_SECTIONS.terms ? termsRef.current : privacyRef.current
    if (target) {
      target.scrollIntoView({ behavior: 'smooth', block: 'start' })
    }
  }, [activeSection])

  return (
    <div className="legal-page">
      <header className="legal-header">
        <div className="legal-brand">
          <img className="logo-icon" src="/app-icon.png" alt="N01 logo" />
          <span className="logo-text">N01</span>
        </div>
        <button className="legal-back" type="button" onClick={onClose}>
          Back to Home
        </button>
      </header>

      <section className="legal-hero">
        <span className="legal-eyebrow">LEGAL</span>
        <h1>Privacy Policy & Terms of Service</h1>
        <p className="legal-intro">Read how SHIFT N0.1 handles your data and the terms for using the app.</p>
        <div className="legal-nav">
          <button
            className={`legal-tab ${activeSection === LEGAL_SECTIONS.privacy ? 'active' : ''}`}
            type="button"
            onClick={() => setActiveSection(LEGAL_SECTIONS.privacy)}
          >
            Privacy Policy
          </button>
          <button
            className={`legal-tab ${activeSection === LEGAL_SECTIONS.terms ? 'active' : ''}`}
            type="button"
            onClick={() => setActiveSection(LEGAL_SECTIONS.terms)}
          >
            Terms of Service
          </button>
        </div>
      </section>

      <div className="legal-content">
        <section ref={privacyRef} className="legal-section" id="privacy-policy">
          <h2>Privacy Policy</h2>
          <div className="legal-meta">
            <p>
              <strong>Effective date:</strong> 2026-01-01
            </p>
            <p>
              <strong>App:</strong> SHIFT N0.1
            </p>
            <p>
              <strong>Publisher:</strong> Sehit Degirmenci
            </p>
            <p>
              <strong>Contact:</strong> sehit@degirmenci.dk
            </p>
          </div>

          <div className="legal-block">
            <h3>1. Introduction</h3>
            <p>
              This privacy policy explains how we collect, use, and protect your information when you use SHIFT N0.1. We follow
              common, well-established principles for data protection and only process information necessary for the app's
              functionality.
            </p>
          </div>

          <div className="legal-block">
            <h3>2. Information we collect</h3>
            <h4>2.1 Information you provide</h4>
            <p>When you use the app, we may process the following information:</p>
            <ul className="legal-list">
              <li>Email address (when creating an account)</li>
              <li>Name and any title (if you choose to enter it)</li>
              <li>Information about your goals, habits, and notes that you create in the app</li>
            </ul>
            <h4>2.2 Technical information</h4>
            <p>The app stores certain technical information and settings to function properly, including:</p>
            <ul className="legal-list">
              <li>App settings and preferences</li>
              <li>Information about use of the app's features</li>
            </ul>
            <p className="legal-note">This information is used solely to ensure stable operation and a better user experience.</p>
          </div>

          <div className="legal-block">
            <h3>3. Purpose of processing</h3>
            <p>We use your information to:</p>
            <ul className="legal-list">
              <li>Provide the app's features</li>
              <li>Enable you to create and manage goals and habits</li>
              <li>Ensure your data can be preserved if you switch devices</li>
              <li>Comply with applicable law</li>
            </ul>
          </div>

          <div className="legal-block">
            <h3>4. Sharing of information</h3>
            <p>We do not share your personal data with third parties unless:</p>
            <ul className="legal-list">
              <li>it is necessary for operating the app,</li>
              <li>required by law, or</li>
              <li>you have given consent.</li>
            </ul>
            <p>We never sell your information.</p>
          </div>

          <div className="legal-block">
            <h3>5. Storage and deletion</h3>
            <p>Your information is stored only as long as necessary for the purpose.</p>
            <p>You can stop using the app at any time and request deletion of your information.</p>
          </div>

          <div className="legal-block">
            <h3>6. Your rights</h3>
            <p>You have the right to:</p>
            <ul className="legal-list">
              <li>access your information</li>
              <li>have incorrect information corrected</li>
              <li>have your information deleted</li>
              <li>object to processing</li>
            </ul>
            <p>Requests can be directed to: sehit@degirmenci.dk</p>
          </div>

          <div className="legal-block">
            <h3>7. Security</h3>
            <p>
              We use common and recognized security measures to protect your information against unauthorized access, loss, or
              misuse.
            </p>
          </div>

          <div className="legal-block">
            <h3>8. Changes</h3>
            <p>
              This privacy policy may be updated. For material changes, you will be informed in the app or via an updated version of
              the policy.
            </p>
          </div>
        </section>

        <section ref={termsRef} className="legal-section" id="terms-of-service">
          <h2>Terms of Service</h2>
          <div className="legal-meta">
            <p>
              <strong>Effective date:</strong> 2026-01-01
            </p>
            <p>
              <strong>Publisher:</strong> Sehit Degirmenci
            </p>
            <p>
              <strong>Contact:</strong> sehit@degirmenci.dk
            </p>
          </div>

          <div className="legal-block">
            <h3>1. Acceptance of terms</h3>
            <p>By using SHIFT N0.1, you accept these terms. If you do not accept the terms, the app may not be used.</p>
          </div>

          <div className="legal-block">
            <h3>2. Purpose of the app</h3>
            <p>SHIFT N0.1 is a tool to help users plan, track, and complete personal goals and habits.</p>
          </div>

          <div className="legal-block">
            <h3>3. User account</h3>
            <p>Some features require you to create an account.</p>
            <p>You are responsible for the information you provide and for protecting your login credentials.</p>
          </div>

          <div className="legal-block">
            <h3>4. User content</h3>
            <p>All content you create in the app (for example, goals, notes, and habits) belongs to you.</p>
            <p>You give us the right to process this content solely for the purpose of providing the app's features.</p>
          </div>

          <div className="legal-block">
            <h3>5. Acceptable use</h3>
            <p>The app may only be used for lawful purposes. It is not permitted to:</p>
            <ul className="legal-list">
              <li>misuse the app,</li>
              <li>attempt to gain unauthorized access to systems or data,</li>
              <li>use the app in a way that can harm other users or the service.</li>
            </ul>
          </div>

          <div className="legal-block">
            <h3>6. Availability</h3>
            <p>
              We strive to keep the app stable and available, but we cannot guarantee uninterrupted operation. Features may change or
              be updated over time.
            </p>
          </div>

          <div className="legal-block">
            <h3>7. Termination</h3>
            <p>You can stop using the app at any time.</p>
            <p>We reserve the right to close an account if the terms are violated.</p>
          </div>

          <div className="legal-block">
            <h3>8. Disclaimer</h3>
            <p>
              SHIFT N0.1 is a personal planning tool and does not constitute medical, psychological, or professional advice. The app
              is provided "as is".
            </p>
          </div>

          <div className="legal-block">
            <h3>9. Limitation of liability</h3>
            <p>
              To the extent permitted by law, Sehit Degirmenci is not liable for indirect loss, data loss, or losses resulting from use
              of the app.
            </p>
          </div>

          <div className="legal-block">
            <h3>10. Governing law</h3>
            <p>These terms are governed by Danish law, and any disputes are decided by Danish courts.</p>
          </div>

          <div className="legal-block">
            <h3>11. Contact</h3>
            <p>Questions regarding terms or use of the app can be directed to: sehit@degirmenci.dk</p>
          </div>
        </section>
      </div>
    </div>
  )
}

export default App
