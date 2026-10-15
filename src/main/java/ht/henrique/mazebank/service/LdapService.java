package ht.henrique.mazebank.service;

import ht.henrique.mazebank.exception.DatabaseException;

import java.util.Map;

public interface LdapService {
    void createLdapUser(String uid, String username, String email, String password) throws DatabaseException;

    Map<String, Object> searchLdapUser(String attribute, String value);

    boolean authenticate(String userKey, String password);
}
