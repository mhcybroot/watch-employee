package mh.cyb.root.watch_employee.controller;

import mh.cyb.root.watch_employee.entity.ActivityLog;
import mh.cyb.root.watch_employee.repository.ActivityLogRepository;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Controller
public class AdminController {

    private final ActivityLogRepository repository;
    private final mh.cyb.root.watch_employee.repository.EmployeeRepository employeeRepository;
    private final mh.cyb.root.watch_employee.repository.DomainCategoryRepository domainCategoryRepository;

    public AdminController(ActivityLogRepository repository,
            mh.cyb.root.watch_employee.repository.EmployeeRepository employeeRepository,
            mh.cyb.root.watch_employee.repository.DomainCategoryRepository domainCategoryRepository) {
        this.repository = repository;
        this.employeeRepository = employeeRepository;
        this.domainCategoryRepository = domainCategoryRepository;
    }

    @GetMapping("/admin/categories")
    public String listCategories(Model model) {
        model.addAttribute("categories", domainCategoryRepository.findAll());
        return "categories";
    }

    @PostMapping("/admin/categories")
    public String saveCategory(
            @org.springframework.web.bind.annotation.ModelAttribute mh.cyb.root.watch_employee.entity.DomainCategory category) {
        domainCategoryRepository.save(category);
        return "redirect:/admin/categories";
    }

    @PostMapping("/admin/categories/delete")
    public String deleteCategory(@org.springframework.web.bind.annotation.RequestParam String domain) {
        domainCategoryRepository.deleteById(domain);
        return "redirect:/admin/categories";
    }

    @GetMapping("/admin")
    public String adminDashboard(
            @org.springframework.web.bind.annotation.RequestParam(required = false) String startDate,
            @org.springframework.web.bind.annotation.RequestParam(required = false) String endDate,
            @org.springframework.web.bind.annotation.RequestParam(defaultValue = "0") int page,
            @org.springframework.web.bind.annotation.RequestParam(defaultValue = "20") int size,
            Model model) {

        // Parse filter dates
        java.time.LocalDateTime startDateTime = null;
        java.time.LocalDateTime endDateTime = null;

        if (startDate != null && !startDate.isBlank()) {
            startDateTime = java.time.LocalDate.parse(startDate).atStartOfDay();
        }
        if (endDate != null && !endDate.isBlank()) {
            endDateTime = java.time.LocalDate.parse(endDate).atTime(23, 59, 59);
        }

        // 1. Logs Table with Pagination & DATE FILTER
        org.springframework.data.domain.Pageable pageable = org.springframework.data.domain.PageRequest.of(page, size,
                Sort.by(Sort.Direction.DESC, "startTime"));

        // Use a generic filtered query for the dashboard (deviceId is null)
        org.springframework.data.domain.Page<ActivityLog> logPage;
        if (startDateTime != null || endDateTime != null) {
            // Need a repository method for global filtered logs
            logPage = repository.findGlobalFiltered(startDateTime, endDateTime, pageable);
        } else {
            logPage = repository.findAll(pageable);
        }

        model.addAttribute("logs", logPage.getContent());
        model.addAttribute("currentPage", page);
        model.addAttribute("totalPages", logPage.getTotalPages());
        model.addAttribute("totalItems", logPage.getTotalElements());
        model.addAttribute("pageSize", size);

        // 2. Employee Map (null-safe: auto-created employees may have null names)
        java.util.Map<String, String> employeeMap = employeeRepository.findAll().stream()
                .collect(java.util.stream.Collectors.toMap(
                        mh.cyb.root.watch_employee.entity.Employee::getDeviceId,
                        e -> e.getName() != null ? e.getName() : "Unknown",
                        (a, b) -> a));
        model.addAttribute("employeeMap", employeeMap);

        // 3. Summary Metrics (respecting filters)
        long totalDuration;
        long activeToday;
        if (startDateTime != null || endDateTime != null) {
            totalDuration = repository.getGlobalTotalDurationFiltered(startDateTime, endDateTime);
            activeToday = repository.countGlobalActiveDevicesFiltered(startDateTime, endDateTime);
        } else {
            totalDuration = repository.getTotalDurationSeconds();
            activeToday = repository.countActiveDevicesSince(java.time.LocalDate.now().atStartOfDay());
        }
        long totalEmployees = employeeRepository.count();

        model.addAttribute("totalDuration", formatDuration(totalDuration));
        model.addAttribute("totalEmployees", totalEmployees);
        model.addAttribute("activeToday", activeToday);

        // 4. Chart Data
        model.addAttribute("activityByHour", repository.getActivityByHour());
        model.addAttribute("topDomains", repository.getTopDomains());

        // Pass filters back
        model.addAttribute("filterStartDate", startDate != null ? startDate : "");
        model.addAttribute("filterEndDate", endDate != null ? endDate : "");

        return "admin";
    }

    private String formatDuration(long seconds) {
        long hours = seconds / 3600;
        long minutes = (seconds % 3600) / 60;
        return String.format("%dh %dm", hours, minutes);
    }

    @GetMapping("/admin/devices")
    public String devices(Model model) {
        // Get unique device IDs from logs
        List<String> deviceIds = repository.findDistinctDeviceIds();
        // Get existing employees
        List<mh.cyb.root.watch_employee.entity.Employee> employees = employeeRepository.findAll();

        // Create a merged list: start with all employees, then add log-only devices
        java.util.Map<String, mh.cyb.root.watch_employee.entity.Employee> viewMap = new java.util.LinkedHashMap<>();

        // Add all registered employees first
        for (mh.cyb.root.watch_employee.entity.Employee emp : employees) {
            viewMap.put(emp.getDeviceId(), emp);
        }

        // Add devices from logs that aren't registered yet
        for (String id : deviceIds) {
            if (!viewMap.containsKey(id)) {
                viewMap.put(id, new mh.cyb.root.watch_employee.entity.Employee(id, null, null));
            }
        }

        model.addAttribute("devices", new java.util.ArrayList<>(viewMap.values()));
        return "devices";
    }

    @org.springframework.web.bind.annotation.PostMapping("/admin/employees")
    public String saveEmployee(
            @org.springframework.web.bind.annotation.ModelAttribute mh.cyb.root.watch_employee.entity.Employee employee) {
        employeeRepository.save(employee);
        return "redirect:/admin/devices";
    }

    @org.springframework.web.bind.annotation.PostMapping("/admin/employees/delete")
    public String deleteEmployee(@org.springframework.web.bind.annotation.RequestParam String deviceId) {
        employeeRepository.deleteById(deviceId);
        return "redirect:/admin/devices";
    }

    @GetMapping("/admin/export")
    public void exportToCSV(
            @org.springframework.web.bind.annotation.RequestParam(required = false) String deviceId,
            @org.springframework.web.bind.annotation.RequestParam(required = false) String startDate,
            @org.springframework.web.bind.annotation.RequestParam(required = false) String endDate,
            jakarta.servlet.http.HttpServletResponse response) throws java.io.IOException {

        response.setContentType("text/csv");
        String filename = "activity_export_" + java.time.LocalDate.now() + ".csv";
        response.setHeader("Content-Disposition", "attachment; filename=" + filename);

        java.time.LocalDateTime startDateTime = (startDate != null && !startDate.isBlank())
                ? java.time.LocalDate.parse(startDate).atStartOfDay()
                : null;
        java.time.LocalDateTime endDateTime = (endDate != null && !endDate.isBlank())
                ? java.time.LocalDate.parse(endDate).atTime(23, 59, 59)
                : null;

        java.util.List<ActivityLog> logs;
        if (deviceId != null && !deviceId.isBlank()) {
            logs = repository.findByDeviceIdFiltered(deviceId, startDateTime, endDateTime, null,
                    org.springframework.data.domain.Pageable.unpaged()).getContent();
        } else {
            logs = repository
                    .findGlobalFiltered(startDateTime, endDateTime, org.springframework.data.domain.Pageable.unpaged())
                    .getContent();
        }

        java.io.PrintWriter writer = response.getWriter();
        writer.println("Device ID,User Email,Domain,URL,Start Time,End Time,Duration (Seconds)");

        for (ActivityLog log : logs) {
            writer.printf("%s,%s,%s,\"%s\",%s,%s,%d%n",
                    log.getDeviceId(),
                    log.getUserEmail(),
                    log.getDomain(),
                    log.getUrl().replace("\"", "\"\""),
                    log.getStartTime(),
                    log.getEndTime(),
                    log.getDurationSeconds());
        }
        writer.flush();
    }

    @GetMapping("/admin/activity/{deviceId}")
    public String employeeActivity(
            @org.springframework.web.bind.annotation.PathVariable String deviceId,
            @org.springframework.web.bind.annotation.RequestParam(required = false) String startDate,
            @org.springframework.web.bind.annotation.RequestParam(required = false) String endDate,
            @org.springframework.web.bind.annotation.RequestParam(required = false) String domain,
            @org.springframework.web.bind.annotation.RequestParam(defaultValue = "0") int page,
            @org.springframework.web.bind.annotation.RequestParam(defaultValue = "20") int size,
            Model model) {

        // Parse filter dates
        java.time.LocalDateTime startDateTime = null;
        java.time.LocalDateTime endDateTime = null;
        String filterDomain = (domain != null && !domain.isBlank()) ? domain : null;

        if (startDate != null && !startDate.isBlank()) {
            startDateTime = java.time.LocalDate.parse(startDate).atStartOfDay();
        }
        if (endDate != null && !endDate.isBlank()) {
            endDateTime = java.time.LocalDate.parse(endDate).atTime(23, 59, 59);
        }

        // Employee info
        mh.cyb.root.watch_employee.entity.Employee employee = employeeRepository.findById(deviceId)
                .orElse(new mh.cyb.root.watch_employee.entity.Employee(deviceId, "Unknown Device", null));
        model.addAttribute("employee", employee);

        // Filtered logs with pagination
        org.springframework.data.domain.Pageable pageable = org.springframework.data.domain.PageRequest.of(page, size,
                Sort.by(Sort.Direction.DESC, "startTime"));
        org.springframework.data.domain.Page<ActivityLog> logPage = repository.findByDeviceIdFiltered(deviceId,
                startDateTime, endDateTime, filterDomain, pageable);

        model.addAttribute("logs", logPage.getContent());
        model.addAttribute("currentPage", page);
        model.addAttribute("totalPages", logPage.getTotalPages());
        model.addAttribute("totalItems", logPage.getTotalElements());
        model.addAttribute("pageSize", size);

        // Summary metrics (filtered but not paginated)
        long totalDuration = repository.getTotalDurationByDeviceIdFiltered(deviceId, startDateTime, endDateTime,
                filterDomain);
        long logCount = repository.countByDeviceIdFiltered(deviceId, startDateTime, endDateTime, filterDomain);
        model.addAttribute("totalDuration", formatDuration(totalDuration));
        model.addAttribute("logCount", logCount);

        // 5. Domain Breakdown Stats & Productivity Scoring
        java.util.List<java.util.Map<String, Object>> stats = repository.getDomainStatsByDeviceIdFiltered(deviceId,
                startDateTime, endDateTime);
        java.util.Map<String, String> categoryMap = domainCategoryRepository.findAll().stream()
                .collect(java.util.stream.Collectors.toMap(mh.cyb.root.watch_employee.entity.DomainCategory::getDomain,
                        mh.cyb.root.watch_employee.entity.DomainCategory::getCategory));

        long productiveSeconds = 0;
        long unproductiveSeconds = 0;
        long totalSecondsByStats = 0;
        long maxDuration = 1;

        for (java.util.Map<String, Object> stat : stats) {
            long duration = (long) stat.get("totalDuration");
            if (duration > maxDuration)
                maxDuration = duration;
            totalSecondsByStats += duration;

            String domainName = (String) stat.get("domain");
            String cat = "Neutral";

            // 1. Try exact match
            if (categoryMap.containsKey(domainName)) {
                cat = categoryMap.get(domainName);
            } else {
                // 2. Try suffix match (e.g. "docs.spring.io" matches "spring.io")
                for (java.util.Map.Entry<String, String> entry : categoryMap.entrySet()) {
                    String key = entry.getKey();
                    if (domainName.endsWith("." + key)) {
                        cat = entry.getValue();
                        break;
                    }
                }
            }

            if ("Productive".equalsIgnoreCase(cat))
                productiveSeconds += duration;
            else if ("Unproductive".equalsIgnoreCase(cat))
                unproductiveSeconds += duration;
        }

        java.util.List<java.util.Map<String, Object>> formattedStats = new java.util.ArrayList<>();
        for (java.util.Map<String, Object> stat : stats) {
            java.util.Map<String, Object> entry = new java.util.HashMap<>(stat);
            long duration = (long) stat.get("totalDuration");
            entry.put("formattedDuration", formatDuration(duration));
            entry.put("percentage", totalSecondsByStats > 0 ? (duration * 100) / totalSecondsByStats : 0);
            formattedStats.add(entry);
        }

        int score = (totalSecondsByStats > 0) ? (int) ((productiveSeconds * 100) / totalSecondsByStats) : 0;

        model.addAttribute("domainStats", formattedStats);
        model.addAttribute("productivityScore", score);
        model.addAttribute("productiveTime", formatDuration(productiveSeconds));
        model.addAttribute("unproductiveTime", formatDuration(unproductiveSeconds));
        model.addAttribute("domainCategories", categoryMap);

        // Domain list for dropdown
        java.util.List<String> domains = repository.findDistinctDomainsByDeviceId(deviceId);
        model.addAttribute("domains", domains);

        // Find top domain
        String topDomain = "-";
        if (!stats.isEmpty()) {
            topDomain = (String) stats.get(0).get("domain");
        }
        model.addAttribute("topDomain", topDomain);

        // Pass current filter values back to repopulate form
        model.addAttribute("filterStartDate", startDate != null ? startDate : "");
        model.addAttribute("filterEndDate", endDate != null ? endDate : "");
        model.addAttribute("filterDomain", domain != null ? domain : "");

        return "employee_activity";
    }

    // Debug endpoint to manually seed categories (admin-protected)
    @GetMapping("/admin/debug/seed")
    @ResponseBody
    public String seedCategories() {
        if (domainCategoryRepository.count() == 0) {
            java.util.List<mh.cyb.root.watch_employee.entity.DomainCategory> categories = java.util.Arrays.asList(
                    new mh.cyb.root.watch_employee.entity.DomainCategory("github.com", "Productive"),
                    new mh.cyb.root.watch_employee.entity.DomainCategory("stackoverflow.com", "Productive"),
                    new mh.cyb.root.watch_employee.entity.DomainCategory("jira.atlassian.com", "Productive"),
                    new mh.cyb.root.watch_employee.entity.DomainCategory("docs.oracle.com", "Productive"),
                    new mh.cyb.root.watch_employee.entity.DomainCategory("spring.io", "Productive"),
                    new mh.cyb.root.watch_employee.entity.DomainCategory("baeldung.com", "Productive"),
                    new mh.cyb.root.watch_employee.entity.DomainCategory("chatgpt.com", "Productive"),
                    new mh.cyb.root.watch_employee.entity.DomainCategory("google.com", "Productive"),
                    new mh.cyb.root.watch_employee.entity.DomainCategory("localhost", "Productive"),
                    new mh.cyb.root.watch_employee.entity.DomainCategory("facebook.com", "Unproductive"),
                    new mh.cyb.root.watch_employee.entity.DomainCategory("youtube.com", "Unproductive"),
                    new mh.cyb.root.watch_employee.entity.DomainCategory("twitter.com", "Unproductive"),
                    new mh.cyb.root.watch_employee.entity.DomainCategory("instagram.com", "Unproductive"),
                    new mh.cyb.root.watch_employee.entity.DomainCategory("reddit.com", "Unproductive"),
                    new mh.cyb.root.watch_employee.entity.DomainCategory("netflix.com", "Unproductive"),
                    new mh.cyb.root.watch_employee.entity.DomainCategory("tiktok.com", "Unproductive"));
            domainCategoryRepository.saveAll(categories);
            return "Seeded " + categories.size() + " categories.";
        }
        return "Categories already exist.";
    }
}
