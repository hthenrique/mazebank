package ht.henrique.mazebank.service.impl;

import ht.henrique.mazebank.exception.DatabaseException;
import ht.henrique.mazebank.model.BaseResponse;
import ht.henrique.mazebank.model.create.CreateRequest;
import ht.henrique.mazebank.model.create.CreateResponse;
import ht.henrique.mazebank.model.database.User;
import ht.henrique.mazebank.model.fetch.FetchUserResponse;
import ht.henrique.mazebank.model.mapper.UserMapper;
import ht.henrique.mazebank.model.reposiory.UserRepository;
import ht.henrique.mazebank.service.ManagementService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
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
            log.info("User already used with key");
            throw new DatabaseException(HttpStatus.CONFLICT, 409000, "User already exists");
        }

        User user = userMapper.createToUser(createRequest);

        try {
            user.setUser_balance(BigDecimal.valueOf(100));
            userRepository.save(user);
        }catch (DataIntegrityViolationException exception){
            log.info("Required field not informed");
            throw new DatabaseException(HttpStatus.BAD_REQUEST, 400009, "Required field not informed");
        }catch (Exception exception){
            throw new DatabaseException(HttpStatus.INTERNAL_SERVER_ERROR, 500000, "Database unavailable");
        }

        return ResponseEntity.status(HttpStatus.CREATED).body(new BaseResponse(201000, new CreateResponse("Success")));
    }

    @Override
    public ResponseEntity<BaseResponse> getUser(String userKey) throws DatabaseException {

        User user = findUserByKey(userKey);

        if (user == null){
            log.info("User not found");
            throw new DatabaseException(HttpStatus.CONFLICT, 404000, "User not found");
        }

        FetchUserResponse fetchUser = userMapper.userToFetchUser(user);

        return ResponseEntity.ok(new BaseResponse(200000, fetchUser));
    }

    private User findUserByKey(String userKey) throws DatabaseException {
        List<User> listUser;
        User user = null;

        log.info("Searching for user with key: " + userKey);
        listUser = userRepository.findByUserEmail(userKey);

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
