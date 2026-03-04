import mysql.connector

def get_db():
    return mysql.connector.connect(
        host="10.19.204.240",
        port=3368,
        user="user_srtb",
        password="SRTB!2026@",
        database="base_global"  
    )