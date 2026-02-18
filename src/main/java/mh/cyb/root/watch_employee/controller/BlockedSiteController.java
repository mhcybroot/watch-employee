package mh.cyb.root.watch_employee.controller;

import mh.cyb.root.watch_employee.entity.BlockedSite;
import mh.cyb.root.watch_employee.repository.BlockedSiteRepository;
import mh.cyb.root.watch_employee.repository.EmployeeRepository;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Controller
public class BlockedSiteController {

    private final BlockedSiteRepository blockedSiteRepository;
    private final EmployeeRepository employeeRepository;

    public BlockedSiteController(BlockedSiteRepository blockedSiteRepository, EmployeeRepository employeeRepository) {
        this.blockedSiteRepository = blockedSiteRepository;
        this.employeeRepository = employeeRepository;
    }

    // --- API for Extension ---

    @GetMapping("/api/blocked-sites")
    @ResponseBody
    public List<String> getBlockedDomains(@RequestParam(required = false) String deviceId) {
        if (deviceId == null || deviceId.isBlank()) {
            // If no device ID, return only global blocks (or maybe all? let's return
            // global)
            return blockedSiteRepository.findByDeviceIdIsNull().stream()
                    .map(BlockedSite::getDomain)
                    .collect(Collectors.toList());
        }
        return blockedSiteRepository.findByDeviceIdOrGlobal(deviceId).stream()
                .map(BlockedSite::getDomain)
                .distinct()
                .collect(Collectors.toList());
    }

    // --- Admin UI ---

    @GetMapping("/admin/blocking")
    public String blockingPage(Model model) {
        List<BlockedSite> blockedSites = blockedSiteRepository.findAll();
        model.addAttribute("blockedSites", blockedSites);

        // Employee map for display
        Map<String, String> employeeMap = employeeRepository.findAll().stream()
                .collect(Collectors.toMap(
                        mh.cyb.root.watch_employee.entity.Employee::getDeviceId,
                        e -> {
                            String name = e.getName() != null ? e.getName() : "Unknown";
                            String dept = e.getDepartment() != null ? e.getDepartment() : "N/A";
                            return name + " (" + dept + ")";
                        },
                        (a, b) -> a // Merge function in case of duplicates
                ));
        model.addAttribute("employeeMap", employeeMap);
        model.addAttribute("employees", employeeRepository.findAll()); // For dropdown

        return "blocking";
    }

    @PostMapping("/admin/blocking")
    public String addBlock(@RequestParam String domain, @RequestParam(required = false) List<String> deviceIds) {
        if (domain != null && !domain.isBlank()) {
            // Normalize domain: remove protocol, www, and path
            String normalizedDomain = domain.trim()
                    .toLowerCase()
                    .replaceAll("^https?://", "")
                    .replaceAll("^www\\.", "")
                    .split("/")[0]; // Remove path if present

            if (!normalizedDomain.isBlank()) {
                if (deviceIds == null || deviceIds.isEmpty() || (deviceIds.size() == 1 && deviceIds.get(0).isBlank())) {
                    // Global Block (no specific devices selected, or explicit empty option)
                    BlockedSite site = new BlockedSite(normalizedDomain, null);
                    blockedSiteRepository.save(site);
                } else {
                    // Create a rule for each selected device
                    for (String deviceId : deviceIds) {
                        if (!deviceId.isBlank()) { // Skip empty values if any mixed in
                            BlockedSite site = new BlockedSite(normalizedDomain, deviceId);
                            blockedSiteRepository.save(site);
                        }
                    }
                }
            }
        }
        return "redirect:/admin/blocking";
    }

    @PostMapping("/admin/blocking/delete")
    public String removeBlock(@RequestParam Long id) {
        blockedSiteRepository.deleteById(id);
        return "redirect:/admin/blocking";
    }
}
