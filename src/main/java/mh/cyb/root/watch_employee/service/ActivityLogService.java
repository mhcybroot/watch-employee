package mh.cyb.root.watch_employee.service;

import mh.cyb.root.watch_employee.entity.ActivityLog;
import mh.cyb.root.watch_employee.repository.ActivityLogRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.List;

@Service
public class ActivityLogService {

    private final ActivityLogRepository repository;

    public ActivityLogService(ActivityLogRepository repository) {
        this.repository = repository;
    }

    @Transactional
    public List<ActivityLog> saveBatch(List<ActivityLog> logs) {
        logs.forEach(log -> {
            if (log.getUrl() != null && log.getDomain() == null) {
                log.setDomain(extractDomain(log.getUrl()));
            }
        });
        return repository.saveAll(logs);
    }

    private String extractDomain(String url) {
        try {
            URI uri = new URI(url);
            String domain = uri.getHost();
            return domain != null ? domain.startsWith("www.") ? domain.substring(4) : domain : url;
        } catch (URISyntaxException e) {
            return url; // Fallback to returning the URL if parsing fails
        }
    }
}
