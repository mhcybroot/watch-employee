package mh.cyb.root.watch_employee.entity;

import jakarta.persistence.*;

@Entity
@Table(name = "domain_categories")
public class DomainCategory {

    @Id
    private String domain;

    @Column(nullable = false)
    private String category; // e.g., "Productive", "Unproductive", "Neutral"

    public DomainCategory() {
    }

    public DomainCategory(String domain, String category) {
        this.domain = domain;
        this.category = category;
    }

    public String getDomain() {
        return domain;
    }

    public void setDomain(String domain) {
        this.domain = domain;
    }

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }
}
