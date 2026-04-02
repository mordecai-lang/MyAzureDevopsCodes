document.addEventListener("DOMContentLoaded", function() {
    var API_BASE = "http://192.168.80.129:5003";
    var registerBtn = document.getElementById("registerBtn");
    var msg = document.getElementById("register-msg");

    registerBtn.addEventListener("click", function() {
        handleRegister();
    });

    async function handleRegister() {
        var username = document.getElementById("username").value.trim();
        var password = document.getElementById("password").value.trim();
        var confirmPassword = document.getElementById("confirm-password").value.trim();

        if (!username || !password || !confirmPassword) {
            msg.style.color = "red";
            msg.textContent = "All fields are required.";
            return;
        }

        if (password !== confirmPassword) {
            msg.style.color = "red";
            msg.textContent = "Passwords do not match.";
            return;
        }

        try {
            var response = await fetch(API_BASE + "/register", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ username: username, password: password }),
                credentials: "include"
            });

            var data = await response.json();

            if (response.ok) {
                msg.style.color = "green";
                msg.textContent = data.message;
                setTimeout(function() {
                    window.location.href = "/login";
                }, 1000);
            } else {
                msg.style.color = "red";
                msg.textContent = data.error || "Registration failed";
            }
        } catch (err) {
            msg.style.color = "red";
            msg.textContent = "Server error, try again later.";
            console.error("Register error:", err);
        }
    }
});
