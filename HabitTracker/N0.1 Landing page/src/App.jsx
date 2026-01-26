import './App.css'
import { BarChart3, Bell, Instagram, Target, Twitter } from 'lucide-react'

function App() {
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
          <h1 className="hero-title reveal">Build Better Habits{'\n'}Transform Your Life</h1>
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
          <h2>Everything You Need to{'\n'}Build Lasting Habits</h2>
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
          <h2>Start Building Better{'\n'}Habits Today</h2>
          <p>Join the NO.1 club and become NO.1{'\n'} Download now and take the first step.</p>
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
            <span>Privacy Policy</span>
            <span>Terms of Service</span>
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

export default App
