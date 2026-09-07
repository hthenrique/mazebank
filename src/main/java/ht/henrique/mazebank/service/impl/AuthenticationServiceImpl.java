package ht.henrique.mazebank.service.impl;

import ht.henrique.mazebank.exception.DatabaseException;
import ht.henrique.mazebank.exception.UtilsException;
import ht.henrique.mazebank.model.BaseResponse;
import ht.henrique.mazebank.model.authenticate.AuthenticateRequest;
import ht.henrique.mazebank.model.authenticate.AuthenticateResponse;
import ht.henrique.mazebank.model.database.User;
import ht.henrique.mazebank.model.type.ReturnCode;
import ht.henrique.mazebank.service.AuthenticateService;
import ht.henrique.mazebank.service.LdapService;
import ht.henrique.mazebank.service.ManagementService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class AuthenticationServiceImpl implements AuthenticateService {

    @Autowired
    private ManagementService managementService;

    @Autowired
    private LdapService ldapService;

    @Override
    public BaseResponse authenticate(AuthenticateRequest authenticateRequest) throws DatabaseException, UtilsException {
        User user = managementService.findUserInDatabase(authenticateRequest.getUsername());

        if (user == null){
            log.info("User with key: " + authenticateRequest.getUsername() + " not found");
            throw new DatabaseException(ReturnCode.NOT_FOUND, "User not found");
        }

        boolean authenticated = false;

        // Valida no LDAP PingDirectory (por UID randômico, username/cn ou e-mail/mail)
        if (!authenticated) {
            authenticated = (user.get_uid() != null && ldapService.authenticate(user.get_uid(), authenticateRequest.getUserpass()))
                    || (user.get_userName() != null && ldapService.authenticate(user.get_userName(), authenticateRequest.getUserpass()))
                    || (user.get_userEmail() != null && ldapService.authenticate(user.get_userEmail(), authenticateRequest.getUserpass()));
        }

        if (!authenticated) {
            log.info("Invalid credentials");
            throw new DatabaseException(ReturnCode.INVALID_PARAMETERS, "Invalid credentials");
        }

        log.info("Logged with success");
        return new BaseResponse(ReturnCode.SUCCESS.getCode(), new AuthenticateResponse("Success"));
    }

}
