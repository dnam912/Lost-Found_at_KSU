// Frontend validation only. Authentication requires server-side API endpoints.
const loginForm = document.getElementById("login-form");
const signupForm = document.getElementById("signup-form");
const form = loginForm || signupForm;

/*if (form) {
    form.addEventListener("submit", (event) => {
        event.preventDefault();

        const message = document.getElementById("form-message");
        const email = form.elements.email.value.trim().toLowerCase();
        const password = form.elements.password.value;

        function showMessage(text, type = "error") {
            message.textContent = text;
            message.className = `form-message ${type}`;
        }

        if (!email.endsWith("@kent.edu") || email.split("@").length !== 2) {
            showMessage("Please enter a valid @kent.edu email address.");
            return;
        }

        if (signupForm) {
            const confirmPassword = form.elements.confirm_password.value;
            if (password.length < 8) {
                showMessage("Password must contain at least 8 characters.");
                return;
            }
            if (password !== confirmPassword) {
                showMessage("Passwords do not match.");
                return;
            }
        }

        // No fetch call here until a matching FastAPI auth route is implemented.
        // The backend must hash passwords, validate identities and set sessions.
        showMessage("Form validated. Authentication is not connected yet.", "info");
    });
}*/

if (form) {
    form.addEventListener("submit", async (event) => {
        event.preventDefault();

        const message = document.getElementById("form-message");
        const submitButton = form.querySelector('button[type="submit"]');
        const email = form.elements.email.value.trim().toLowerCase();
        const password = form.elements.password.value;

        function showMessage(text, type = "error", showResend = false) {
            message.textContent = text;
            message.className = `form-message ${type}`;

            if (showResend) {
                const resendBtn = document.createElement("button");
                resendBtn.type = "button";
                resendBtn.className = "resend-link";
                resendBtn.textContent = " Resend verification email";
                resendBtn.addEventListener("click", async () => {
                    resendBtn.disabled = true;
                    try {
                        const res = await fetch("/api/auth/resend-verification", {
                            method: "POST",
                            headers: { "Content-Type": "application/json" },
                            body: JSON.stringify({ email })
                        });
                        const data = await res.json();
                        showMessage(data.message || "Verification email resent.", "info");
                    } catch {
                        showMessage("Failed to resend verification email.");
                    }
                });
                message.appendChild(resendBtn);
            }
        }

        if (!email.endsWith("@kent.edu") || email.split("@").length !== 2) {
            showMessage("Please enter a valid @kent.edu email address.");
            return;
        }

        if (signupForm) {
            const confirmPassword = form.elements.confirm_password.value;
            if (password.length < 12) {
                showMessage("Password must contain at least 12 characters.");
                return;
            }
            if (password !== confirmPassword) {
                showMessage("Passwords do not match.");
                return;
            }
        }

        submitButton.disabled = true;
        try {
            const endpoint = signupForm ? "/api/auth/signup" : "/api/auth/login";
            const response = await fetch(endpoint, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ email, password })
            });
            const result = await response.json();

            if (!response.ok) {
                const detail = typeof result.detail === "string" ? result.detail : "Authentication failed.";
                const needsVerification = response.status === 403;
                showMessage(detail, "error", needsVerification);
                return;
            }

            if (signupForm) {
                showMessage(result.message || "Check your @kent.edu inbox for the verification link.", "info", true);
                form.reset();
            } else {
                localStorage.setItem("access_token", result.access_token);
                window.location.href = "/static/index.html";
            }
        } catch (error) {
            console.error(error);
            showMessage("Unable to reach the server.");
        } finally {
            submitButton.disabled = false;
        }
    });
}