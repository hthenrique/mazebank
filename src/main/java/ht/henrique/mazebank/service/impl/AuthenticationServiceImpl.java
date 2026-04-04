package ht.henrique.mazebank.service.impl;

import ht.henrique.mazebank.exception.DatabaseException;
import ht.henrique.mazebank.exception.UtilsException;
import ht.henrique.mazebank.model.BaseResponse;
import ht.henrique.mazebank.model.authenticate.AuthenticateRequest;
import ht.henrique.mazebank.model.authenticate.AuthenticateResponse;
import ht.henrique.mazebank.model.database.User;
import ht.henrique.mazebank.model.type.ReturnCode;
import ht.henrique.mazebank.service.AuthenticateService;
import ht.henrique.mazebank.util.HashString;
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
    public BaseResponse authenticate(AuthenticateRequest authenticateRequest) throws DatabaseException, UtilsException {
        User user = managementService.findUserInDatabase(authenticateRequest.getUsername());

        if (user == null){
            log.info("User with key: " + authenticateRequest.getUsername() + " not found");
            throw new DatabaseException(ReturnCode.NOT_FOUND, "User not found");
        }

        if (!HashString.hash(authenticateRequest.getUserpass()).equals(user.get_userPass())){
            log.info("Invalid credentials");
            throw new DatabaseException(ReturnCode.INVALID_PARAMETERS, "Invalid credentials");
        }

        log.info("Logged with success");
        return new BaseResponse(ReturnCode.SUCCESS.getCode(), new AuthenticateResponse("Success"));
    }

}
