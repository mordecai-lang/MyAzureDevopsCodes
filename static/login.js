document.addEventListener("DOMContentLoaded", function() {
    var API_BASE = "http://192.168.80.129:5003";
    var loginBtn = document.getElementById("loginBtn");
    var msg = document.getElementById("login-msg");

    loginBtn.addEventListener("click", function() {
        handleLogin();
    });

    async function handleLogin() {
        var username = document.getElementById("username").value.trim();
        var password = document.getElementById("password").value.trim();

        if (!username || !password) {
            msg.style.color = "red";
            msg.textContent = "Please enter both username and password.";
            return;
        }

        try {
            var response = await fetch(API_BASE + "/login", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ username: username, password: password }),
                credentials: "include"
            });

            var data = await response.json();

            if (response.ok) {
                msg.style.color = "green";
                msg.textContent = data.message;
                // Redirect to main page after 1 second
                setTimeout(function() {
                    window.location.href = "/dashboard";
                }, 1000);
            } else {
                msg.style.color = "red";
                msg.textContent = data.error || "Login failed";
            }
        } catch (err) {
            msg.style.color = "red";
            msg.textContent = "Server error, try again later.";
            console.error("Login error:", err);
        }
    }
});
