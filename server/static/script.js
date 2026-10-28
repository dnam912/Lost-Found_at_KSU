// The UI relies only on /api/auth/me; production authentication can keep this contract.
const state = { authenticated: false, mode: "search", searchedValues: null };
const form = document.getElementById("report_form");
const button = document.getElementById("submit_button");
const feedback = document.getElementById("search_feedback");

function escapeHtml(value) {
    return String(value ?? "").replaceAll("&", "&amp;").replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&#039;");
}

function formValues() {
    return {
        status: document.querySelector('input[name="item_status"]:checked').value,
        location: document.getElementById("location_select").value,
        date: document.getElementById("estimated_date").value,
        estimated_start: document.getElementById("estimated_start").value,
        estimated_end: document.getElementById("estimated_end").value,
        category: document.getElementById("category_input").value,
        color: document.getElementById("color_input").value,
        material: document.getElementById("material_input").value,
        text: document.getElementById("description_raw").value
    };
}

function toFormData(values, includeImage = false) {
    const data = new FormData();
    Object.entries(values).forEach(([key, value]) => data.append(key, value));
    const image = document.getElementById("image_file").files[0];
    if (includeImage && image) data.append("image", image);
    return data;
}

function setMode(mode) {
    state.mode = mode;
    button.textContent = mode === "report" ? "Submit Report" : "Search Matches";
}

function showFeedback(message, showReport = false) {
    feedback.innerHTML = `<p>${escapeHtml(message)}</p>` + (showReport
        ? '<button type="button" class="report-option" id="report_option">Report an Item</button>' : "");
    feedback.hidden = false;
    if (showReport) {
        document.getElementById("report_option").addEventListener("click", () => {
            if (state.authenticated) {
                setMode("report");
                showFeedback("No matches found. Your entries are preserved. Select Submit Report to save your report.");
            } else {
                showFeedback("Login required to submit a report.");
            }
        });
    }
}

function renderMatches(matches) {
    const container = document.getElementById("matching_items");
    const section = document.getElementById("matching_section");
    container.innerHTML = matches.map(item => `
        <article class="match-card">
            <div class="match-image">${item.image_path
                ? `<img src="${escapeHtml(item.image_path)}" alt="Reported item">` : "No image"}</div>
            <h3>${escapeHtml(item.category || "Unknown Item")}</h3>
            <div class="match-meta">
                <span class="badge ${escapeHtml((item.status || "").toLowerCase())}">${escapeHtml(item.status)}</span>
                <span class="match-score">${Number(item.score)}% match</span>
            </div>
            <p class="match-location">${escapeHtml(item.location || "Unknown")}
              ${item.estimated_date ? " · " + escapeHtml(item.estimated_date) : ""}</p>
        </article>`).join("");
    section.hidden = matches.length === 0;
}

async function fetchJSON(url, options) {
    const response = await fetch(url, options);
    const result = await response.json();
    if (!response.ok) {
        const detail = result.detail;
        throw new Error(typeof detail === "string" ? detail : detail?.message || "Request failed");
    }
    return result;
}

async function refreshAuth() {
    try {
        const result = await fetchJSON("/api/auth/me", { credentials: "same-origin" });
        state.authenticated = result.authenticated === true;
    } catch (error) {
        console.error("Auth state unavailable:", error);
        state.authenticated = false;
    }
    document.getElementById("image_upload_row").hidden = !state.authenticated;
    if (!state.authenticated && state.mode === "report") setMode("search");
}

async function searchMatches(values) {
    const result = await fetchJSON("/api/web/match", { method: "POST", body: toFormData(values), credentials: "same-origin" });
    document.getElementById("json_result").textContent = JSON.stringify(result, null, 2);
    renderMatches(result.matches);
    if (result.matches.length) {
        showFeedback(`${result.matches.length} matching item(s) found.`);
        document.getElementById("matching_section").scrollIntoView({ behavior: "smooth", block: "start" });
    } else {
        showFeedback("No matching items found. Would you like to report your item?", true);
    }
}

async function submitReport(values) {
    if (!state.authenticated) {
        showFeedback("Login required to submit a report.");
        return;
    }
    const result = await fetchJSON("/api/process", {
        method: "POST", body: toFormData(values, true), credentials: "same-origin"
    });
    document.getElementById("json_result").textContent = JSON.stringify(result.parsed_data, null, 2);
    setMode("search");
    showFeedback("Report submitted successfully.");
    if (document.getElementById("developer_details").open) await loadReports();
}

form.addEventListener("submit", async event => {
    event.preventDefault();
    // Never allow field edits after a no-result search to submit unchecked data.
    const values = formValues();
    if (state.mode === "report" && JSON.stringify(values) !== JSON.stringify(state.searchedValues)) {
        setMode("search");
        showFeedback("Details changed. Search again before submitting a report.");
        return;
    }
    button.disabled = true;
    const label = button.textContent;
    button.textContent = state.mode === "report" ? "Submitting..." : "Searching...";
    try {
        if (state.mode === "report") {
            await submitReport(values);
        } else {
            setMode("search");
            state.searchedValues = values;
            await searchMatches(values);
        }
    } catch (error) {
        console.error(error);
        showFeedback(error.message);
    } finally {
        button.disabled = false;
        button.textContent = state.mode === "report" ? "Submit Report" : "Search Matches";
    }
});

form.addEventListener("input", event => {
    if (event.target.id === "image_file") return;
    if (state.mode === "report") {
        setMode("search");
        showFeedback("Details updated. Search again to check for matches.");
    }
});

async function loadReports() {
    const container = document.getElementById("reports_container");
    container.textContent = "Loading...";
    try {
        const reports = await fetchJSON("/api/reports");
        container.innerHTML = reports.length ? reports.map(report => `
            <article class="report-card">
                ${report.image_path ? `<img src="${escapeHtml(report.image_path)}" alt="Reported item">` : ""}
                <h3>${escapeHtml(report.category || "Unknown Item")}</h3>
                <p><strong>Status:</strong> ${escapeHtml(report.status)}</p>
                <p><strong>Location:</strong> ${escapeHtml(report.location)}</p>
                <p><strong>Date:</strong> ${escapeHtml(report.estimated_date || "Unknown")}</p>
                <p><strong>Color:</strong> ${escapeHtml(report.color || "-")}</p>
                <p><strong>Material:</strong> ${escapeHtml(report.material || "-")}</p>
                <p><strong>Description:</strong> ${escapeHtml(report.description_raw || "-")}</p>
            </article>`).join("") : "<p>No reports yet.</p>";
    } catch (error) {
        container.textContent = "Failed to load reports.";
        console.error(error);
    }
}

document.getElementById("developer_details").addEventListener("toggle", event => {
    if (event.target.open) loadReports();
});
setMode("search");
refreshAuth();
