package mh.cyb.root.watch_employee.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "activity_logs_v2", indexes = {
        @Index(name = "idx_activity_user_email", columnList = "userEmail"),
        @Index(name = "idx_activity_start_time", columnList = "startTime"),
        @Index(name = "idx_activity_device_id", columnList = "deviceId")
})
public class ActivityLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    @NotBlank(message = "User email is required")
    @Email(message = "Invalid email format")
    private String userEmail;

    @Column(columnDefinition = "TEXT", nullable = false)
    @NotBlank(message = "URL is required")
    private String url;

    private String domain;

    @Column(nullable = false)
    @NotNull(message = "Start time is required")
    private LocalDateTime startTime;

    private LocalDateTime endTime;

    @Min(value = 0, message = "Duration cannot be negative")
    private Long durationSeconds;

    @Column(nullable = false)
    @NotBlank(message = "Device ID is required")
    private String deviceId;

    // Constructors
    public ActivityLog() {
    }

    public ActivityLog(String userEmail, String url, String domain, LocalDateTime startTime, LocalDateTime endTime,
            Long durationSeconds, String deviceId) {
        this.userEmail = userEmail;
        this.url = url;
        this.domain = domain;
        this.startTime = startTime;
        this.endTime = endTime;
        this.durationSeconds = durationSeconds;
        this.deviceId = deviceId;
    }

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getUserEmail() {
        return userEmail;
    }

    public void setUserEmail(String userEmail) {
        this.userEmail = userEmail;
    }

    public String getUrl() {
        return url;
    }

    public void setUrl(String url) {
        this.url = url;
    }

    public String getDomain() {
        return domain;
    }

    public void setDomain(String domain) {
        this.domain = domain;
    }

    public LocalDateTime getStartTime() {
        return startTime;
    }

    public void setStartTime(LocalDateTime startTime) {
        this.startTime = startTime;
    }

    public LocalDateTime getEndTime() {
        return endTime;
    }

    public void setEndTime(LocalDateTime endTime) {
        this.endTime = endTime;
    }

    public Long getDurationSeconds() {
        return durationSeconds;
    }

    public void setDurationSeconds(Long durationSeconds) {
        this.durationSeconds = durationSeconds;
    }

    public String getDeviceId() {
        return deviceId;
    }

    public void setDeviceId(String deviceId) {
        this.deviceId = deviceId;
    }
}
