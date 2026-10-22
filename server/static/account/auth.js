// Frontend validation only. Authentication requires server-side API endpoints.
const loginForm = document.getElementById("login-form");
const signupForm = document.getElementById("signup-form");
const form = loginForm || signupForm;

if (form) {
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
}
