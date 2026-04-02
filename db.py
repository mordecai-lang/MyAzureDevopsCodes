import mysql.connector

def get_db():
    db = mysql.connector.connect(
        host="localhost",
        user="flask-app-user",
        password="abc123",
        database="task_manager"
    )
    cursor = db.cursor(dictionary=True)  # dictionary=True helps fetch columns by name
    return db, cursor
