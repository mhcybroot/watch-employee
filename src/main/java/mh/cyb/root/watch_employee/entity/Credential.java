package mh.cyb.root.watch_employee.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "credentials")
public class Credential {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String siteName;

    @Column(nullable = false)
    private String siteUrl;

    @Column(nullable = false)
    private String username;

    @Column(nullable = false, length = 512)
    private String encryptedPassword;

    @Column(length = 500)
    private String notes;

    @Column(nullable = true)
    private String submittedByDeviceId;

    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    public Credential() {
    }

    public Credential(String siteName, String siteUrl, String username, String encryptedPassword, String notes) {
        this.siteName = siteName;
        this.siteUrl = siteUrl;
        this.username = username;
        this.encryptedPassword = encryptedPassword;
        this.notes = notes;
        this.createdAt = LocalDateTime.now();
    }

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getSiteName() {
        return siteName;
    }

    public void setSiteName(String siteName) {
        this.siteName = siteName;
    }

    public String getSiteUrl() {
        return siteUrl;
    }

    public void setSiteUrl(String siteUrl) {
        this.siteUrl = siteUrl;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getEncryptedPassword() {
        return encryptedPassword;
    }

    public void setEncryptedPassword(String encryptedPassword) {
        this.encryptedPassword = encryptedPassword;
    }

    public String getNotes() {
        return notes;
    }

    public void setNotes(String notes) {
        this.notes = notes;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public String getSubmittedByDeviceId() {
        return submittedByDeviceId;
    }

    public void setSubmittedByDeviceId(String submittedByDeviceId) {
        this.submittedByDeviceId = submittedByDeviceId;
    }
}
