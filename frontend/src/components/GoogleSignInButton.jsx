import { useEffect, useRef, useState } from 'react';

const GOOGLE_SCRIPT_SRC = 'https://accounts.google.com/gsi/client';
let googleCredentialListener = null;
let initializedGoogleClientId = null;

const setGoogleCredentialListener = (listener) => {
  googleCredentialListener = listener;
};

const forwardGoogleCredential = (response) => {
  if (typeof googleCredentialListener === 'function') {
    googleCredentialListener(response);
  }
};

const loadGoogleScript = () => new Promise((resolve, reject) => {
  if (window.google?.accounts?.id) {
    resolve();
    return;
  }

  const timeoutId = window.setTimeout(() => {
    reject(new Error('Google script load timed out.'));
  }, 12000);

  const complete = () => {
    window.clearTimeout(timeoutId);
    resolve();
  };

  const fail = () => {
    window.clearTimeout(timeoutId);
    reject(new Error('Failed to load Google script.'));
  };

  const existing = document.querySelector(`script[src="${GOOGLE_SCRIPT_SRC}"]`);
  if (existing) {
    existing.addEventListener('load', () => complete(), { once: true });
    existing.addEventListener('error', () => fail(), { once: true });

    if (window.google?.accounts?.id) {
      complete();
    }

    return;
  }

  const script = document.createElement('script');
  script.src = GOOGLE_SCRIPT_SRC;
  script.async = true;
  script.defer = true;
  script.onload = () => complete();
  script.onerror = () => fail();
  document.head.appendChild(script);
});

const ensureGoogleInitialized = (clientId) => {
  if (!window.google?.accounts?.id) {
    throw new Error('Google Identity Services SDK is unavailable.');
  }

  if (initializedGoogleClientId === clientId) {
    return;
  }

  window.google.accounts.id.initialize({
    client_id: clientId,
    callback: (response) => {
      forwardGoogleCredential(response);
    },
  });

  initializedGoogleClientId = clientId;
};

export default function GoogleSignInButton({ onCredential, disabled }) {
  const buttonContainerRef = useRef(null);
  const onCredentialRef = useRef(onCredential);
  const disabledRef = useRef(disabled);
  const [status, setStatus] = useState({
    loading: true,
    enabled: false,
    message: '',
  });

  useEffect(() => {
    onCredentialRef.current = onCredential;
  }, [onCredential]);

  useEffect(() => {
    disabledRef.current = disabled;
  }, [disabled]);

  useEffect(() => {
    setGoogleCredentialListener((response) => {
      if (disabledRef.current) {
        return;
      }

      if (response?.credential) {
        onCredentialRef.current(response.credential);
      }
    });

    return () => {
      setGoogleCredentialListener(null);
    };
  }, []);

  useEffect(() => {
    let active = true;

    const initGoogleAuth = async () => {
      try {
        const res = await fetch('/api/auth/google/config');
        const config = await res.json();

        if (!res.ok || !config.enabled || !config.clientId) {
          if (active) {
            setStatus({
              loading: false,
              enabled: false,
              message: 'Google sign-in is not configured yet.',
            });
          }
          return;
        }

        await loadGoogleScript();

        if (!active || !window.google?.accounts?.id) {
          return;
        }

        ensureGoogleInitialized(config.clientId);

        if (buttonContainerRef.current) {
          buttonContainerRef.current.innerHTML = '';
          const width = Math.min(buttonContainerRef.current.clientWidth || 320, 340);

          window.google.accounts.id.renderButton(buttonContainerRef.current, {
            type: 'standard',
            shape: 'pill',
            theme: 'outline',
            text: 'continue_with',
            size: 'large',
            width,
          });

          const waitForRenderedButton = (attempt = 0) => {
            if (!active || !buttonContainerRef.current) {
              return;
            }

            const hasRenderedButton = Boolean(
              buttonContainerRef.current.querySelector('iframe, [role="button"], .nsm7Bb-HzV7m-LgbsSe')
            );

            if (hasRenderedButton) {
              setStatus({
                loading: false,
                enabled: true,
                message: '',
              });
              return;
            }

            if (attempt >= 20) {
              setStatus({
                loading: false,
                enabled: false,
                message: 'Google sign-in could not be displayed. Add this site origin in Google OAuth settings and disable script blockers.',
              });
              return;
            }

            window.setTimeout(() => {
              waitForRenderedButton(attempt + 1);
            }, 250);
          };

          waitForRenderedButton();
        } else {
          setStatus({
            loading: false,
            enabled: false,
            message: 'Unable to mount Google sign-in container.',
          });
        }
      } catch (err) {
        if (active) {
          setStatus({
            loading: false,
            enabled: false,
            message: 'Unable to load Google sign-in right now. Verify Authorized JavaScript origins and browser blockers.',
          });
        }
      }
    };

    initGoogleAuth();

    return () => {
      active = false;
    };
  }, []);

  if (!status.loading && !status.enabled) {
    return <p className="oauth-note oauth-note-warning">{status.message}</p>;
  }

  return (
    <>
      <div className={`google-btn-wrap ${disabled ? 'google-btn-disabled' : ''}`}>
        <div ref={buttonContainerRef} />
      </div>
      {status.loading && <p className="oauth-note">Loading Google sign-in...</p>}
    </>
  );
}
