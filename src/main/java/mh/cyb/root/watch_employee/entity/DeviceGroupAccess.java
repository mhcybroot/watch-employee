package mh.cyb.root.watch_employee.entity;

import jakarta.persistence.*;

@Entity
@Table(name = "device_group_access", uniqueConstraints = @UniqueConstraint(columnNames = { "group_id", "device_id" }))
public class DeviceGroupAccess {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "group_id", nullable = false)
    private CredentialGroup group;

    @Column(name = "device_id", nullable = false)
    private String deviceId;

    public DeviceGroupAccess() {
    }

    public DeviceGroupAccess(CredentialGroup group, String deviceId) {
        this.group = group;
        this.deviceId = deviceId;
    }

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public CredentialGroup getGroup() {
        return group;
    }

    public void setGroup(CredentialGroup group) {
        this.group = group;
    }

    public String getDeviceId() {
        return deviceId;
    }

    public void setDeviceId(String deviceId) {
        this.deviceId = deviceId;
    }
}
