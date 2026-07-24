# Use Cases

Version: 1.0.0

Status: APPROVED

---

# UC-001

Create Ride

Primary Actor

Organizer

Preconditions

User is authenticated locally.

Flow

1. Open Activities.
2. Press Create.
3. Enter ride information.
4. Select activity type.
5. Select meeting point.
6. Select date and time.
7. Save activity.
8. Invitations are generated.

Result

Ride is created.

---

# UC-002

Join Ride

Actor

Participant

Flow

Receive invitation.

↓

Open activity.

↓

Read details.

↓

Accept.

Result

Participant becomes visible in participant list.

---

# UC-003

Ride Start

Actor

Participant

Flow

Open activity.

↓

Press Start Ride.

↓

GPS permission verified.

↓

GPS sharing enabled.

↓

WebRTC session established.

↓

Live Mode activated.

---

# UC-004

Ride Finish

Actor

Organizer

Flow

Press Finish.

↓

Activity closes.

↓

Archive created.

↓

Notifications sent.

---

# UC-005

Offline Recovery

Actor

System

Internet connection lost.

↓

Offline Mode enabled.

↓

Changes stored locally.

↓

Internet restored.

↓

Synchronization.

↓

Offline Mode ends.

---

# UC-006

Arrival Notification

Actor

System

Participant approaches meeting point.

↓

Distance threshold reached.

↓

Generate notification.

↓

Notify organizer and participants.

---

End of document.