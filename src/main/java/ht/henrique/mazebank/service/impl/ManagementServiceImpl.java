package ht.henrique.mazebank.service.impl;

import ht.henrique.mazebank.exception.DatabaseException;
import ht.henrique.mazebank.model.BaseResponse;
import ht.henrique.mazebank.model.authenticate.AuthenticateResponse;
import ht.henrique.mazebank.model.create.CreateRequest;
import ht.henrique.mazebank.model.create.CreateResponse;
import ht.henrique.mazebank.model.database.User;
import ht.henrique.mazebank.model.mapper.UserMapper;
import ht.henrique.mazebank.model.reposiory.UserRepository;
import ht.henrique.mazebank.service.ManagementService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@Slf4j
public class ManagementServiceImpl implements ManagementService {
    @Autowired
    private UserRepository userRepository;

    @Autowired
    private UserMapper userMapper;

    @Override
    public ResponseEntity<BaseResponse> createUser(CreateRequest createRequest) throws DatabaseException {

        if (findUserByKey(createRequest.getUseremail()) != null){
            throw new DatabaseException(HttpStatus.CONFLICT, 409000, "User already used");
        }

        User user = userMapper.createToUser(createRequest);

        try {
            userRepository.save(user);
        }catch (DataIntegrityViolationException exception){
            throw new DatabaseException(HttpStatus.BAD_REQUEST, 400009, "Required field not informed");
        }catch (Exception exception){
            throw new DatabaseException(HttpStatus.INTERNAL_SERVER_ERROR, 500000, "Database unavailable");
        }

        return ResponseEntity.status(HttpStatus.CREATED).body(new BaseResponse(201000, new CreateResponse("Success")));
    }

    private User findUserByKey(String userKey) throws DatabaseException {
        List<User> listUser;
        User user = null;

        log.info("Searching for user with key: " + userKey);
        listUser = userRepository.findByUserAccountKey(userKey);

        if (listUser.size() == 1){
            user = listUser.get(0);
        }else {
            if (listUser.size() > 1){
                throw new DatabaseException(HttpStatus.UNPROCESSABLE_ENTITY, 420000, "More than one user");
            }
        }
        return user;
    }
}
