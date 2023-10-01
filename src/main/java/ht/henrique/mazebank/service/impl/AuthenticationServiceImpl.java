package ht.henrique.mazebank.service.impl;

import ht.henrique.mazebank.exception.DatabaseException;
import ht.henrique.mazebank.model.BaseResponse;
import ht.henrique.mazebank.model.authenticate.AuthenticateRequest;
import ht.henrique.mazebank.model.authenticate.AuthenticateResponse;
import ht.henrique.mazebank.model.database.User;
import ht.henrique.mazebank.service.AuthenticateService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class AuthenticationServiceImpl implements AuthenticateService {

    @Autowired
    private ManagementServiceImpl managementService;

    @Override
    public BaseResponse authenticate(AuthenticateRequest authenticateRequest) throws DatabaseException {
        User user = managementService.findUserInDatabase(authenticateRequest.getUsername());

        if (user == null){
            log.info("User with key: " + authenticateRequest.getUsername() + " not found");
            throw new DatabaseException(HttpStatus.NOT_FOUND, 404000, "User not found");
        }

        if (!authenticateRequest.getUserpass().equals(user.get_userPass())){
            log.info("Invalid credentials");
            throw new DatabaseException(HttpStatus.BAD_REQUEST, 400000, "Invalid credentials");
        }

        log.info("Logged with success");
        return new BaseResponse(200000, new AuthenticateResponse("Success"));
    }

}
