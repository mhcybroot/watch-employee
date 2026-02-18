package mh.cyb.root.watch_employee.service;

import mh.cyb.root.watch_employee.entity.*;
import mh.cyb.root.watch_employee.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.stream.Collectors;

@Service
public class CredentialService {

    private final CredentialRepository credentialRepo;
    private final CredentialGroupRepository groupRepo;
    private final CredentialGroupMappingRepository mappingRepo;
    private final DeviceGroupAccessRepository accessRepo;
    private final EncryptionService encryptionService;

    public CredentialService(CredentialRepository credentialRepo,
            CredentialGroupRepository groupRepo,
            CredentialGroupMappingRepository mappingRepo,
            DeviceGroupAccessRepository accessRepo,
            EncryptionService encryptionService) {
        this.credentialRepo = credentialRepo;
        this.groupRepo = groupRepo;
        this.mappingRepo = mappingRepo;
        this.accessRepo = accessRepo;
        this.encryptionService = encryptionService;
    }

    // ========== Credential CRUD ==========

    public List<Credential> getAllCredentials() {
        return credentialRepo.findAll();
    }

    public Optional<Credential> getCredentialById(Long id) {
        return credentialRepo.findById(id);
    }

    public Credential saveCredential(String siteName, String siteUrl, String username,
            String plainPassword, String notes) {
        String encrypted = encryptionService.encrypt(plainPassword);
        Credential cred = new Credential(siteName, siteUrl, username, encrypted, notes);
        return credentialRepo.save(cred);
    }

    public Credential updateCredential(Long id, String siteName, String siteUrl, String username,
            String plainPassword, String notes) {
        Credential cred = credentialRepo.findById(id)
                .orElseThrow(() -> new RuntimeException("Credential not found: " + id));
        cred.setSiteName(siteName);
        cred.setSiteUrl(siteUrl);
        cred.setUsername(username);
        if (plainPassword != null && !plainPassword.isBlank()) {
            cred.setEncryptedPassword(encryptionService.encrypt(plainPassword));
        }
        if (notes != null) {
            cred.setNotes(notes);
        }
        return credentialRepo.save(cred);
    }

    @Transactional
    public void deleteCredential(Long id) {
        mappingRepo.deleteByCredentialId(id);
        credentialRepo.deleteById(id);
    }

    public String decryptPassword(Long credentialId) {
        Credential cred = credentialRepo.findById(credentialId)
                .orElseThrow(() -> new RuntimeException("Credential not found: " + credentialId));
        return encryptionService.decrypt(cred.getEncryptedPassword());
    }

    // ========== Group CRUD ==========

    public List<CredentialGroup> getAllGroups() {
        return groupRepo.findAll();
    }

    public Optional<CredentialGroup> getGroupById(Long id) {
        return groupRepo.findById(id);
    }

    public CredentialGroup saveGroup(String name, String description) {
        return groupRepo.save(new CredentialGroup(name, description));
    }

    public CredentialGroup updateGroup(Long id, String name, String description) {
        CredentialGroup group = groupRepo.findById(id)
                .orElseThrow(() -> new RuntimeException("Group not found: " + id));
        group.setName(name);
        group.setDescription(description);
        return groupRepo.save(group);
    }

    @Transactional
    public void deleteGroup(Long id) {
        mappingRepo.deleteByGroupId(id);
        accessRepo.deleteByGroupId(id);
        groupRepo.deleteById(id);
    }

    // ========== Group ↔ Credential Mapping ==========

    public List<Credential> getCredentialsByGroup(Long groupId) {
        return mappingRepo.findByGroupId(groupId).stream()
                .map(CredentialGroupMapping::getCredential)
                .collect(Collectors.toList());
    }

    public List<Long> getCredentialIdsByGroup(Long groupId) {
        return mappingRepo.findByGroupId(groupId).stream()
                .map(m -> m.getCredential().getId())
                .collect(Collectors.toList());
    }

    @Transactional
    public void assignCredentialsToGroup(Long groupId, List<Long> credentialIds) {
        CredentialGroup group = groupRepo.findById(groupId)
                .orElseThrow(() -> new RuntimeException("Group not found: " + groupId));

        // Remove existing mappings
        mappingRepo.deleteByGroupId(groupId);

        // Add new mappings
        for (Long credId : credentialIds) {
            Credential cred = credentialRepo.findById(credId)
                    .orElseThrow(() -> new RuntimeException("Credential not found: " + credId));
            mappingRepo.save(new CredentialGroupMapping(cred, group));
        }
    }

    public long getCredentialCountForGroup(Long groupId) {
        return mappingRepo.countByGroupId(groupId);
    }

    // ========== Device ↔ Group Access ==========

    public List<String> getDeviceIdsByGroup(Long groupId) {
        return accessRepo.findByGroupId(groupId).stream()
                .map(DeviceGroupAccess::getDeviceId)
                .collect(Collectors.toList());
    }

    @Transactional
    public void assignDevicesToGroup(Long groupId, List<String> deviceIds) {
        CredentialGroup group = groupRepo.findById(groupId)
                .orElseThrow(() -> new RuntimeException("Group not found: " + groupId));

        // Remove existing access
        accessRepo.deleteByGroupId(groupId);

        // Add new access
        for (String deviceId : deviceIds) {
            accessRepo.save(new DeviceGroupAccess(group, deviceId));
        }
    }

    public long getDeviceCountForGroup(Long groupId) {
        return accessRepo.countByGroupId(groupId);
    }

    // ========== Extension API ==========

    /**
     * Get credentials accessible by a device (without passwords).
     */
    public List<Map<String, Object>> getCredentialsForDevice(String deviceId) {
        List<Credential> credentials = mappingRepo.findCredentialsAccessibleByDevice(deviceId);
        return credentials.stream().map(c -> {
            Map<String, Object> map = new LinkedHashMap<>();
            map.put("id", c.getId());
            map.put("siteName", c.getSiteName());
            map.put("siteUrl", c.getSiteUrl());
            map.put("username", c.getUsername());
            map.put("notes", c.getNotes());
            // NO password field — intentionally omitted
            return map;
        }).collect(Collectors.toList());
    }

    /**
     * Get decrypted password only if device has access.
     */
    public String copyPassword(Long credentialId, String deviceId) {
        // Check group-based access OR own submitted credential
        boolean hasGroupAccess = mappingRepo.hasDeviceAccessToCredential(credentialId, deviceId);
        boolean isOwnCredential = credentialRepo.findById(credentialId)
                .map(c -> deviceId.equals(c.getSubmittedByDeviceId()))
                .orElse(false);

        if (!hasGroupAccess && !isOwnCredential) {
            throw new SecurityException("Device " + deviceId + " does not have access to credential " + credentialId);
        }
        return decryptPassword(credentialId);
    }

    // ========== User-Submitted Credentials ==========

    public Credential saveUserCredential(String deviceId, String siteName, String siteUrl,
            String username, String plainPassword, String notes) {
        String encrypted = encryptionService.encrypt(plainPassword);
        Credential cred = new Credential(siteName, siteUrl, username, encrypted, notes);
        cred.setSubmittedByDeviceId(deviceId);
        return credentialRepo.save(cred);
    }

    public List<Map<String, Object>> getMyCredentials(String deviceId) {
        List<Credential> credentials = credentialRepo.findBySubmittedByDeviceId(deviceId);
        return credentials.stream().map(c -> {
            Map<String, Object> map = new LinkedHashMap<>();
            map.put("id", c.getId());
            map.put("siteName", c.getSiteName());
            map.put("siteUrl", c.getSiteUrl());
            map.put("username", c.getUsername());
            map.put("notes", c.getNotes());
            map.put("createdAt", c.getCreatedAt().toString());
            return map;
        }).collect(Collectors.toList());
    }

    public List<Credential> getUserSubmittedCredentials() {
        return credentialRepo.findBySubmittedByDeviceIdIsNotNull();
    }

    public List<Credential> getAdminCredentials() {
        return credentialRepo.findBySubmittedByDeviceIdIsNull();
    }

    @Transactional
    public boolean deleteUserCredential(Long id, String deviceId) {
        Optional<Credential> opt = credentialRepo.findById(id);
        if (opt.isEmpty())
            return false;
        Credential cred = opt.get();
        if (!deviceId.equals(cred.getSubmittedByDeviceId()))
            return false;
        mappingRepo.deleteByCredentialId(id);
        credentialRepo.deleteById(id);
        return true;
    }
}
