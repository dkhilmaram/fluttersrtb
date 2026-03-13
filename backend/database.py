import mysql.connector

def get_db():
    return mysql.connector.connect(
        host="server680404.ddns.net",
        port=3368,
        user="user_srtb",
        password="SRTB!2026@",
        database="base_global"  
    )