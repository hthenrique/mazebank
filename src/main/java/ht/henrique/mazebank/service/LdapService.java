package ht.henrique.mazebank.service;

import ht.henrique.mazebank.exception.DatabaseException;

public interface LdapService {
    void createLdapUser(String uid, String username, String email, String password) throws DatabaseException;
    boolean authenticate(String userKey, String password);
}
