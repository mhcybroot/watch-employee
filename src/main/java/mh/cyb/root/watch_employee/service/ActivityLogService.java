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

    private final mh.cyb.root.watch_employee.repository.EmployeeRepository employeeRepository;

    public ActivityLogService(ActivityLogRepository repository,
            mh.cyb.root.watch_employee.repository.EmployeeRepository employeeRepository) {
        this.repository = repository;
        this.employeeRepository = employeeRepository;
    }

    @Transactional
    public List<ActivityLog> saveBatch(List<ActivityLog> logs) {
        if (logs.isEmpty())
            return logs;

        // 1. Process Logs (Domain Extraction)
        logs.forEach(log -> {
            if (log.getUrl() != null && log.getDomain() == null) {
                log.setDomain(extractDomain(log.getUrl()));
            }
        });

        // 2. Update Employee Last Seen
        // Assuming all logs in a batch come from the same device (which is true for the
        // extension)
        String deviceId = logs.get(0).getDeviceId();
        if (deviceId != null && !deviceId.isBlank()) {
            mh.cyb.root.watch_employee.entity.Employee employee = employeeRepository.findById(deviceId)
                    .orElse(new mh.cyb.root.watch_employee.entity.Employee(deviceId, null, null));

            employee.setLastSeen(java.time.LocalDateTime.now());
            employeeRepository.save(employee);
        }

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
