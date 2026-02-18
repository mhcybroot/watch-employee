package mh.cyb.root.watch_employee.entity;

import jakarta.persistence.*;

@Entity
@Table(name = "credential_group_mappings", uniqueConstraints = @UniqueConstraint(columnNames = { "credential_id",
        "group_id" }))
public class CredentialGroupMapping {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "credential_id", nullable = false)
    private Credential credential;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "group_id", nullable = false)
    private CredentialGroup group;

    public CredentialGroupMapping() {
    }

    public CredentialGroupMapping(Credential credential, CredentialGroup group) {
        this.credential = credential;
        this.group = group;
    }

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Credential getCredential() {
        return credential;
    }

    public void setCredential(Credential credential) {
        this.credential = credential;
    }

    public CredentialGroup getGroup() {
        return group;
    }

    public void setGroup(CredentialGroup group) {
        this.group = group;
    }
}
