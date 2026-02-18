package mh.cyb.root.watch_employee.repository;

import mh.cyb.root.watch_employee.entity.DomainCategory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface DomainCategoryRepository extends JpaRepository<DomainCategory, String> {
}
