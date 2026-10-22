const demoMatches = [
    { category: "Blue Backpack", status: "Lost", score: 92, location: "Student Center", date: "Dec 12", imageClass: "" },
    { category: "Black Wallet", status: "Found", score: 85, location: "Library", date: "Dec 10", imageClass: "wallet" },
    { category: "Silver Keys", status: "Found", score: 78, location: "Math & Science Building", date: "Dec 9", imageClass: "keys" }
];

function escapeHtml(value) {
    return String(value ?? "")
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");
}

function renderDemoMatches() {
    const section = document.getElementById("matching_section");
    const container = document.getElementById("matching_items");

    container.innerHTML = demoMatches.map(item => `
        <article class="match-card">
            <div class="match-image ${item.imageClass}" aria-hidden="true"></div>
            <h3>${escapeHtml(item.category)}</h3>
            <div class="match-meta">
                <span class="badge ${item.status.toLowerCase()}">${escapeHtml(item.status)}</span>
                <span class="match-score">${item.score}% match</span>
            </div>
            <p class="match-location">${escapeHtml(item.location)} &middot; ${escapeHtml(item.date)}</p>
        </article>
    `).join("");

    section.hidden = false;
}

async function loadReports() {
    const container = document.getElementById("reports_container");
    container.innerHTML = "<p>Loading...</p>";

    try {
        const response = await fetch("/api/reports");
        if (!response.ok) throw new Error("Failed to load reports");

        const reports = await response.json();
        container.innerHTML = "";

        if (reports.length === 0) {
            container.innerHTML = "<p>No reports yet.</p>";
            return;
        }

        reports.forEach(report => {
            const card = document.createElement("article");
            card.className = "report-card";

            const imageHTML = report.image_path
                ? `<img src="${escapeHtml(report.image_path)}" alt="${escapeHtml(report.category || "Reported item")}">`
                : "";
            const timeHTML = report.estimated_start || report.estimated_end
                ? `<p><strong>Time:</strong> ${escapeHtml(report.estimated_start || "?")} - ${escapeHtml(report.estimated_end || "?")}</p>`
                : "";

            card.innerHTML = `
                ${imageHTML}
                <h3>${escapeHtml(report.category || "Unknown Item")}</h3>
                <p><strong>Status:</strong> ${escapeHtml(report.status)}</p>
                <p><strong>Location:</strong> ${escapeHtml(report.location)}</p>
                <p><strong>Date:</strong> ${escapeHtml(report.estimated_date || "Unknown")}</p>
                ${timeHTML}
                <p><strong>Color:</strong> ${escapeHtml(report.color || "-")}</p>
                <p><strong>Material:</strong> ${escapeHtml(report.material || "-")}</p>
                <p><strong>Description:</strong><br>${escapeHtml(report.description_raw || "-")}</p>
            `;
            container.appendChild(card);
        });
    } catch (error) {
        console.error(error);
        container.innerHTML = "<p>Failed to load reports.</p>";
    }
}

async function sendRawDescription(event) {
    event.preventDefault();

    const submitButton = document.getElementById("submit_button");
    const statusValue = document.querySelector('input[name="item_status"]:checked').value;
    const locationValue = document.getElementById("location_select").value;
    const dateValue = document.getElementById("estimated_date").value;
    const startValue = document.getElementById("estimated_start").value;
    const endValue = document.getElementById("estimated_end").value;
    const categoryValue = document.getElementById("category_input").value;
    const colorValue = document.getElementById("color_input").value;
    const materialValue = document.getElementById("material_input").value;
    const textareaValue = document.getElementById("description_raw").value;
    const imageFileInput = document.getElementById("image_file");

    const formData = new FormData();
    formData.append("status", statusValue);
    formData.append("location", locationValue);
    formData.append("date", dateValue);
    formData.append("estimated_start", startValue);
    formData.append("estimated_end", endValue);
    formData.append("category", categoryValue);
    formData.append("color", colorValue);
    formData.append("material", materialValue);
    formData.append("text", textareaValue);

    if (imageFileInput.files[0]) {
        formData.append("image", imageFileInput.files[0]);
    }

    submitButton.disabled = true;
    submitButton.textContent = "Submitting...";

    try {
        const response = await fetch("/api/process", {
            method: "POST",
            body: formData
        });
        const result = await response.json();
        console.log("Result:", result);

        if (response.status === 409) {
            alert("This image has already been uploaded");
            document.getElementById("json_result").innerText = JSON.stringify(result, null, 2);
            return;
        }

        if (!response.ok) throw new Error(result.detail || "Failed to submit report");

        if (result.status === "success") {
            document.getElementById("json_result").innerText = JSON.stringify(result.parsed_data, null, 2);
            renderDemoMatches();
            loadReports();
            document.getElementById("matching_section").scrollIntoView({ behavior: "smooth", block: "start" });
        }
    } catch (error) {
        console.error("SERVER ERROR:", error);
        alert("Unable to submit the report. Please try again.");
    } finally {
        submitButton.disabled = false;
        submitButton.textContent = "Submit";
    }
}

document.getElementById("report_form").addEventListener("submit", sendRawDescription);
loadReports();
