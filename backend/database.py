import mysql.connector

def get_db():
    return mysql.connector.connect(
        host="127.0.0.1",
        port=3306,
        user="root",
        password="",
        database="base_globale"  # ← put it back
    )