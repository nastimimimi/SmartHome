from flask import Flask, request, jsonify
from flask_cors import CORS
import datetime

app = Flask(__name__)
CORS(app)

# Память для данных
rfid_events = []
fire_detected = False
last_color = {"r": 0, "g": 0, "b": 0}


@app.route("/")
def root():
    return "Smart Home Server работает "


# Прием данных от ESP32 
@app.route("/add_rfid", methods=["POST"])
def add_rfid():
    data = request.get_json()
    if not data or "cardID" not in data:
        return jsonify({"status": "error", "message": "Нет cardID"}), 400

    event = {
        "cardID": data["cardID"],
        "success": data.get("success", True),
        "date": datetime.datetime.now().isoformat()
    }
    rfid_events.insert(0, event)
    print("RFID событие:", event)
    return jsonify({"status": "ok", "event": event})


# Получить все события
@app.route("/events", methods=["GET"])
def get_events():
    return jsonify(rfid_events)


# Управление RGB-лентой 
@app.route("/setColor", methods=["GET"])
def set_color():
    global last_color
    try:
        r = int(request.args.get("r", 0))
        g = int(request.args.get("g", 0))
        b = int(request.args.get("b", 0))
        last_color = {"r": r, "g": g, "b": b}
        print(f"🎨 Цвет изменён: R={r}, G={g}, B={b}")
        return jsonify({"ok": True, "color": last_color})
    except Exception as e:
        return jsonify({"error": str(e)}), 400


# Пожарная система 
@app.route("/fire_status", methods=["GET"])
def get_fire_status():
    return jsonify({"fireDetected": fire_detected})


@app.route("/fire/<state>", methods=["GET"])
def set_fire_state(state):
    global fire_detected
    if state == "on":
        fire_detected = True
        print("🔥 Пожар включен вручную!")
    elif state == "off":
        fire_detected = False
        print("Пожар выключен вручную!")
    else:
        return jsonify({"error": "Неверный параметр"}), 400
    return jsonify({"fireDetected": fire_detected})

@app.route("/fire_alert", methods=["POST"])
def fire_alert():
    global fire_detected
    data = request.get_json()
    fire_detected = data.get("fireDetected", False)
    print(f"🚨 Получен сигнал пожарки от ESP32: {fire_detected}")
    return jsonify({"fireDetected": fire_detected})

@app.route("/last_rfid", methods=["GET"])
def get_last_rfid():
    if not rfid_events:
        return jsonify({"status": "empty", "message": "Нет данных"})
    return jsonify(rfid_events[0])


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5002)
