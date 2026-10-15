package ht.henrique.mazebank.service.impl;

import ht.henrique.mazebank.exception.DatabaseException;
import ht.henrique.mazebank.model.type.ReturnCode;
import ht.henrique.mazebank.service.LdapService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.ldap.core.AttributesMapper;
import org.springframework.ldap.core.LdapTemplate;
import org.springframework.ldap.query.LdapQueryBuilder;
import org.springframework.ldap.support.LdapNameBuilder;
import org.springframework.stereotype.Service;

import javax.naming.Name;
import javax.naming.NamingEnumeration;
import javax.naming.directory.Attribute;
import javax.naming.directory.BasicAttribute;
import javax.naming.directory.BasicAttributes;
import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
public class LdapServiceImpl implements LdapService {

    @Autowired
    private LdapTemplate ldapTemplate;

    @Override
    public void createLdapUser(String uid, String username, String email, String password) throws DatabaseException {
        try {
            log.info("Creating LDAP user with uid: {}, username: {}", uid, username);
            Name dn = LdapNameBuilder.newInstance("ou=people")
                    .add("uid", uid)
                    .build();

            BasicAttributes attributes = new BasicAttributes();
            BasicAttribute objectClass = new BasicAttribute("objectClass");
            objectClass.add("top");
            objectClass.add("person");
            objectClass.add("organizationalPerson");
            objectClass.add("inetOrgPerson");
            attributes.put(objectClass);

            attributes.put("uid", uid);
            attributes.put("cn", username);
            attributes.put("sn", username);
            if (email != null && !email.isEmpty()) {
                attributes.put("mail", email);
            }
            if (password != null && !password.isEmpty()) {
                attributes.put("userPassword", password.getBytes(StandardCharsets.UTF_8));
            }

            ldapTemplate.bind(dn, null, attributes);
            log.info("LDAP user created successfully with DN: {}", dn);
        } catch (Exception e) {
            log.error("Failed to create user in LDAP: {}", e.getMessage(), e);
            throw new DatabaseException(ReturnCode.INTERNAL_SERVER_ERROR, "Failed to create user in LDAP: " + e.getMessage());
        }
    }

    @Override
    public Map<String, Object> searchLdapUser(String attribute, String value) {
        if (attribute == null || value == null) {
            return Collections.emptyMap();
        }

        try {
            log.info("Searching LDAP user by attribute '{}' with value '{}'", attribute, value);

            List<Map<String, Object>> results = ldapTemplate.search(
                    LdapQueryBuilder.query()
                            .base("ou=people")
                            .where(attribute).is(value),
                    (AttributesMapper<Map<String, Object>>) attrs -> {
                        Map<String, Object> map = new HashMap<>();
                        NamingEnumeration<? extends Attribute> enumeration = attrs.getAll();
                        while (enumeration.hasMore()) {
                            Attribute attr = enumeration.next();
                            // Pega o valor do atributo (ex: uid, mail, cn, sn, etc.)
                            map.put(attr.getID(), attr.get());
                        }
                        return map;
                    }
            );

            if (!results.isEmpty()) {
                log.info("LDAP user found with attributes: {}", results.get(0).keySet());
                return results.get(0);
            }

            log.info("No LDAP user found for {}={}", attribute, value);
            return Collections.emptyMap();

        } catch (Exception e) {
            log.error("Error searching LDAP user for {}={}: {}", attribute, value, e.getMessage());
            return Collections.emptyMap();
        }
    }

    @Override
    public boolean authenticate(String userKey, String password) {
        if (userKey == null || password == null) {
            return false;
        }
        try {
             ldapTemplate.authenticate(
                    LdapQueryBuilder.query()
                            .base("ou=people")
                            .filter("(|(uid={0})(mail={0})(cn={0}))", userKey),
                    password
            );
             return true;
        } catch (Exception e) {
            log.warn("LDAP authentication failed for userKey '{}': {}", userKey, e.getMessage());
            return false;
        }
    }
}
