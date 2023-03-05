package ht.henrique.mazebank.service.impl;

import ht.henrique.mazebank.exception.DatabaseException;
import ht.henrique.mazebank.model.BaseResponse;
import ht.henrique.mazebank.model.authenticate.AuthenticateRequest;
import ht.henrique.mazebank.model.authenticate.AuthenticateResponse;
import ht.henrique.mazebank.model.database.User;
import ht.henrique.mazebank.model.reposiory.UserRepository;
import ht.henrique.mazebank.service.AuthenticateService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@Slf4j
public class AuthenticationServiceImpl implements AuthenticateService {

    @Autowired
    private UserRepository userRepository;

    @Override
    public ResponseEntity<BaseResponse> authenticate(AuthenticateRequest authenticateRequest) throws DatabaseException {
        List<User> listUser;
        User user = null;

        try {
            log.info("Searching for user with key: " + authenticateRequest.getUsername());
            listUser = userRepository.findByUserEmail(authenticateRequest.getUsername());

            if (listUser.size() == 1){
                user = listUser.get(0);
            }

        }catch (Exception e){
            log.info("Database unavailable");
            throw new DatabaseException(HttpStatus.INTERNAL_SERVER_ERROR, 500000, "Database unavailable");
        }

        if (user == null){
            log.info("User with key: " + authenticateRequest.getUsername() + " not found");
            throw new DatabaseException(HttpStatus.NOT_FOUND, 404000, "User not found");
        }

        if (!authenticateRequest.getUserpass().equals(user.getUser_pass())){
            log.info("Invalid credentials");
            throw new DatabaseException(HttpStatus.BAD_REQUEST, 400000, "Invalid credentials");
        }

        log.info("Logged with success");
        return ResponseEntity.status(HttpStatus.OK).body(new BaseResponse(200000, new AuthenticateResponse("Success")));
    }

}
