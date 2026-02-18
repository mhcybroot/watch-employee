package mh.cyb.root.watch_employee.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "employees")
public class Employee {

    @Id
    private String deviceId;

    private String name;
    private String department;

    @jakarta.persistence.Column(name = "last_seen")
    private java.time.LocalDateTime lastSeen;

    public java.time.LocalDateTime getLastSeen() {
        return lastSeen;
    }

    public void setLastSeen(java.time.LocalDateTime lastSeen) {
        this.lastSeen = lastSeen;
    }

    public String getFormattedLastSeen() {
        if (lastSeen == null)
            return "Never";
        java.time.Duration duration = java.time.Duration.between(lastSeen, java.time.LocalDateTime.now());
        long mins = duration.toMinutes();
        if (mins < 1)
            return "Just now";
        if (mins < 60)
            return mins + "m ago";
        long hours = duration.toHours();
        if (hours < 24)
            return hours + "h ago";
        return duration.toDays() + "d ago";
    }

    public String getStatus() {
        if (lastSeen == null) {
            return "Offline";
        }
        long minutesAgo = java.time.Duration.between(lastSeen, java.time.LocalDateTime.now()).toMinutes();
        if (minutesAgo <= 10) {
            return "Active";
        } else {
            return "Inactive";
        }
    }

    public Employee() {
    }

    public Employee(String deviceId, String name, String department) {
        this.deviceId = deviceId;
        this.name = name;
        this.department = department;
    }

    public String getDeviceId() {
        return deviceId;
    }

    public void setDeviceId(String deviceId) {
        this.deviceId = deviceId;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getDepartment() {
        return department;
    }

    public void setDepartment(String department) {
        this.department = department;
    }
}
