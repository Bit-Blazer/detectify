import sys
from ultralytics import YOLO
import cv2
import time
import os

# Load the trained model
model = YOLO('yolov8n.pt')

# Check if video path argument is provided
if len(sys.argv)<2:
    video_path = sys.argv[0]
    print(video_path,"from file")
    if os.path.isfile(video_path):
        cap = cv2.VideoCapture(video_path)  # Use pre-recorded video
    else:
        print(f"Error: The file '{video_path}' does not exist.")
        sys.exit(1)
else:
    print("from live feed")
    cap = cv2.VideoCapture(0)  # Use live camera feed if no video path is provided

# Confidence thresholds for detection
thresholds = {
    'human': 0.5,
    'cart': 0.6,
    'item': 0.4
}

# Initialize tracking variables
tracked_items = {}  # Dictionary to track items by ID
alerted_items = set()  # Store items that raised an alert

while cap.isOpened():
    start_time = time.time()

    ret, frame = cap.read()
    if not ret:
        break
    
    # Perform inference
    results = model(frame)
    
    # Store detected humans, items, and carts
    humans = []
    carts = []
    items = []
    
    for obj in results[0].boxes:
        confidence = obj.conf.item()
        label = model.names[int(obj.cls)]
        bbox = obj.xyxy[0].tolist()
        
        # Draw labeled bounding boxes
        if confidence >= thresholds.get(label, 0.4):
            cv2.rectangle(frame, (int(bbox[0]), int(bbox[1])), (int(bbox[2]), int(bbox[3])), (0, 255, 0), 2)
            cv2.putText(frame, f'{label} ({confidence:.2f})', (int(bbox[0]), int(bbox[1]-10)), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (36, 255, 12), 2)

        # Add detected objects to respective lists
        if label == 'human' and confidence >= thresholds['human']:
            humans.append(bbox)
        elif label == 'cart' and confidence >= thresholds['cart']:
            carts.append(bbox)
        elif label == 'item' and confidence >= thresholds['item']:
            items.append(bbox)
    
    # Track and check item status
    for item in items:
        item_id = id(item)  # Unique ID for the item (using Python's id())
        tracked_items[item_id] = item  # Add or update the tracked item
        
        # Check if item is inside any human's bounding box
        item_in_human = False
        for human in humans:
            if (human[0] <= item[0] <= human[2]) and (human[1] <= item[1] <= human[3]):
                item_in_human = True
                break
        
        # If the item is in the human box, check for potential theft
        if item_in_human:
            # If item disappears in next frames without going into a cart, raise alert
            if item_id not in alerted_items:
                alerted_items.add(item_id)  # Alert for possible theft
                cv2.putText(frame, 'THEFT ALERT!', (50, 50), cv2.FONT_HERSHEY_SIMPLEX, 2, (0, 0, 255), 3)
    
    # Display FPS
    fps = 1 / (time.time() - start_time)
    cv2.putText(frame, f'FPS: {fps:.2f}', (frame.shape[1] - 150, 50), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
    
    # Display frame
    cv2.imshow('YOLOv8 Detection', frame)
    
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()




