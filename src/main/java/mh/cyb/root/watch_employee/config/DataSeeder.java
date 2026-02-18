package mh.cyb.root.watch_employee.config;

import mh.cyb.root.watch_employee.entity.DomainCategory;
import mh.cyb.root.watch_employee.repository.DomainCategoryRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.util.Arrays;
import java.util.List;

@Component
public class DataSeeder implements CommandLineRunner {

    private final DomainCategoryRepository domainCategoryRepository;

    public DataSeeder(DomainCategoryRepository domainCategoryRepository) {
        this.domainCategoryRepository = domainCategoryRepository;
    }

    @Override
    public void run(String... args) throws Exception {
        if (domainCategoryRepository.count() == 0) {
            List<DomainCategory> categories = Arrays.asList(
                    // Productive
                    new DomainCategory("github.com", "Productive"),
                    new DomainCategory("stackoverflow.com", "Productive"),
                    new DomainCategory("jira.atlassian.com", "Productive"),
                    new DomainCategory("docs.oracle.com", "Productive"),
                    new DomainCategory("spring.io", "Productive"),
                    new DomainCategory("baeldung.com", "Productive"),
                    new DomainCategory("chatgpt.com", "Productive"),
                    new DomainCategory("google.com", "Productive"),
                    new DomainCategory("localhost", "Productive"),

                    // Unproductive
                    new DomainCategory("facebook.com", "Unproductive"),
                    new DomainCategory("youtube.com", "Unproductive"),
                    new DomainCategory("twitter.com", "Unproductive"),
                    new DomainCategory("instagram.com", "Unproductive"),
                    new DomainCategory("reddit.com", "Unproductive"),
                    new DomainCategory("netflix.com", "Unproductive"),
                    new DomainCategory("tiktok.com", "Unproductive"));

            domainCategoryRepository.saveAll(categories);
            System.out.println("Seeded " + categories.size() + " domain categories.");
        }
    }
}
