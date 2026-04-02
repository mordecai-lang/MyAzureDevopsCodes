from flask import Flask, render_template, request, jsonify, session, redirect
from db import get_db   # <-- updated to use get_db()
from flask_bcrypt import Bcrypt
from dotenv import load_dotenv
import os

app = Flask(__name__)
load_dotenv()

app.secret_key = os.getenv("SECRET_KEY")
print("SECRET_KEY:", os.getenv("SECRET_KEY"))
bcrypt = Bcrypt(app)

# ------------------------
# ROOT REDIRECT
# ------------------------
@app.route("/")
def home():
    return redirect("/login")

# ------------------------
# PAGES
# ------------------------
@app.route("/login")
def login_page():
    return render_template("login.html")

@app.route("/register")
def register_page():
    return render_template("register.html")


@app.route("/dashboard")
def dashboard():
    return render_template("index.html")


@app.route("/tasks")
def tasks_page():
    if "user_id" not in session:
        return redirect(url_for("login_page"))
    return render_template("tasks.html")


# ------------------------
# REGISTER API
# ------------------------
@app.route("/register", methods=["POST"])
def register():
    data = request.get_json()
    print("Received JSON:", data)
    username = data.get("username")
    password = data.get("password")

    if not username or not password:
        return jsonify({"error": "Username and password are required"}), 400

    hashed_pw = bcrypt.generate_password_hash(password).decode('utf-8')

    try:
        conn, cursor = get_db()   # <-- use get_db() function
        cursor.execute(
            "INSERT INTO users (username, password_hash) VALUES (%s, %s)",
            (username, hashed_pw)
        )
        conn.commit()
        cursor.close()
        conn.close()
        return jsonify({"message": "User registered successfully"}), 200
    except Exception as e:
        # optional: print(e) for debugging
        return jsonify({"error": "Username already exists"}), 400


# VIEW TASK LOGIC

# ------------------------
# ALL TASKS (READ-ONLY PAGE)
# ------------------------
@app.route("/all_tasks")
def all_tasks_page():
    if "user_id" not in session:
        return redirect("/login")

    conn, cursor = get_db()
    cursor.execute("""
        SELECT day, task_name, task_date, task_time
        FROM tasks
        WHERE user_id = %s
        ORDER BY
            FIELD(day, 'Monday','Tuesday','Wednesday','Thursday','Friday'),
            task_date,
            task_time
    """, (session["user_id"],))

    rows = cursor.fetchall()
    cursor.close()
    conn.close()

    # Group tasks by day
    tasks_by_day = {
        "Monday": [],
        "Tuesday": [],
        "Wednesday": [],
        "Thursday": [],
        "Friday": []
    }

    for row in rows:
        tasks_by_day[row["day"]].append({
            "task_name": row["task_name"],
            "task_date": row["task_date"],
            "task_time": row["task_time"]
        })

    return render_template("all_tasks.html", tasks=tasks_by_day)




# ------------------------
# LOGIN API
# ------------------------
@app.route("/login", methods=["POST"])
def login():
    data = request.get_json()
    username = data.get("username")
    password = data.get("password")

    if not username or not password:
        return jsonify({"error": "Username and password are required"}), 400

    conn, cursor = get_db()   # <-- updated
    cursor.execute("SELECT * FROM users WHERE username=%s", (username,))
    user = cursor.fetchone()
    cursor.close()
    conn.close()

    if user and bcrypt.check_password_hash(user["password_hash"], password):
        session["user_id"] = user["id"]
        session["username"] = username
        return jsonify({"message": "Login successful"}), 200
    else:
        return jsonify({"error": "Invalid credentials"}), 401



# ------------------------
# LOGOUT
# ------------------------
@app.route("/logout", methods=["POST"])
def logout():
    session.clear()
    return jsonify({"message": "Logged out"}), 200

# ------------------------
# TASK API
# ------------------------
@app.route("/add-task", methods=["POST"])
def add_task():
    if "user_id" not in session:
        return jsonify({"error": "Unauthorized"}), 401

    data = request.get_json()
    day = data.get("day")
    task_name = data.get("task_name")
    task_date = data.get("task_date")
    task_time = data.get("task_time")

    conn, cursor = get_db()   # <-- updated
    cursor.execute(
        "INSERT INTO tasks (user_id, day, task_name, task_date, task_time) VALUES (%s, %s, %s, %s, %s)",
        (session["user_id"], day, task_name, task_date, task_time)
    )
    conn.commit()
    cursor.close()
    conn.close()
    return jsonify({"message": "Task added successfully"}), 200

@app.route("/get-tasks")
def get_tasks():
    if "user_id" not in session:
        return jsonify({"error": "Unauthorized"}), 401

    conn, cursor = get_db()   # <-- updated
    cursor.execute(
        "SELECT * FROM tasks WHERE user_id=%s ORDER BY task_date, task_time",
        (session["user_id"],)
    )
    tasks = cursor.fetchall()
    cursor.close()
    conn.close()

    # Convert date and time to strings for JSON
    formatted_tasks = []
    for t in tasks:
        formatted_tasks.append({
            "id": t["id"],
            "day": t["day"],
            "task_name": t["task_name"],
            "task_date": str(t["task_date"]),
            "task_time": str(t["task_time"])
        })

    return jsonify({"tasks": formatted_tasks}), 200

# ------------------------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5003, debug=True)
