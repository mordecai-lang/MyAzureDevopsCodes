const API_BASE = "http://192.168.80.129:5003"; // VM IP and port

// --------------------
// Add task function (global for onclick in HTML)
// --------------------
window.addTask = async function(day) {
    const container = document.getElementById(day);
    const name = container.querySelector(".task-name").value.trim();
    const date = container.querySelector(".task-date").value;
    const time = container.querySelector(".task-time").value;

    if (!name || !date || !time) {
        alert("Please fill all task fields.");
        return;
    }

    const url = API_BASE + "/add-task";

    const payload = {
        day: day,
        task_name: name,
        task_date: date,
        task_time: time
    };

    try {
        const response = await fetch(url, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload),
            credentials: "include" // ensures Flask session is sent
        });

        const data = await response.json();

        if (response.status === 401) {
            alert("Session expired. Please login again.");
            window.location.href = "/login";
            return;
        }

        // Clear input fields
        container.querySelector(".task-name").value = "";
        container.querySelector(".task-date").value = "";
        container.querySelector(".task-time").value = "";

        loadTasks(); // refresh task list
    } catch (err) {
        console.error("Add task error:", err);
        alert("Server error. Try again later.");
    }
};

// --------------------
// Load tasks on page load
// --------------------
async function loadTasks() {
    try {
        const res = await fetch(API_BASE + "/get-tasks", {
            method: "GET",
            credentials: "include"
        });

        if (res.status === 401) {
            alert("Session expired. Please login again.");
            window.location.href = "/login";
            return;
        }

        const data = await res.json();

        // Clear all task lists first
        document.querySelectorAll(".task-list").forEach(ul => ul.innerHTML = "");

        // Populate tasks per day
        data.tasks.forEach(t => {
            const ul = document.getElementById(t.day).querySelector(".task-list");
            const li = document.createElement("li");
            li.textContent = `${t.task_name} — ${t.task_date} ${t.task_time}`;
            ul.appendChild(li);
        });

    } catch (err) {
        console.error("Load tasks error:", err);
    }
}

// Run on page load
window.onload = loadTasks;
