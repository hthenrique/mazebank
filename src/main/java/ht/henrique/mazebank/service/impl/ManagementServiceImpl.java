package ht.henrique.mazebank.service.impl;

import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoCursor;
import com.mongodb.client.MongoDatabase;
import ht.henrique.mazebank.exception.DatabaseException;
import ht.henrique.mazebank.exception.ValidationException;
import ht.henrique.mazebank.model.BaseResponse;
import ht.henrique.mazebank.model.create.CreateRequest;
import ht.henrique.mazebank.model.create.CreateResponse;
import ht.henrique.mazebank.model.database.User;
import ht.henrique.mazebank.model.deposit.DepositRequest;
import ht.henrique.mazebank.model.fetch.FetchUserResponse;
import ht.henrique.mazebank.model.mapper.UserMapper;
import ht.henrique.mazebank.model.type.ReturnCode;
import ht.henrique.mazebank.service.ManagementService;
import ht.henrique.mazebank.util.HashString;
import lombok.extern.slf4j.Slf4j;
import org.bson.Document;
import org.bson.types.Decimal128;
import org.bson.types.ObjectId;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import javax.annotation.PostConstruct;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Slf4j
@Service
public class ManagementServiceImpl implements ManagementService {

    @Autowired
    private UserMapper userMapper;
    @Autowired
    private MongoClient mongoClient;
    private MongoDatabase mongoDatabase;
    private MongoCollection<Document> collection;

    @PostConstruct
    void init(){
        mongoDatabase = mongoClient.getDatabase("Users");
        collection = mongoDatabase.getCollection("users_collection");
    }

    @Override
    public BaseResponse createUser(CreateRequest createRequest) throws DatabaseException, ValidationException {
         User user = findUserInCollection("_userEmail", createRequest.getUseremail());
         if (user != null){
             log.info(String.format("User already exists with uid %s", user.get_id()));
             throw new DatabaseException(ReturnCode.USER_ALREADY_EXISTS, "User already exists");
         }

        if (!isValidEmail(createRequest.getUseremail())) {
            throw new ValidationException(ReturnCode.INVALID_PARAMETERS, "Invalid email");
        }

        try {
            Document document = new Document();
            document.append("_userName", createRequest.getUsername());
            document.append("_userEmail", createRequest.getUseremail());
            document.append("_userPass", HashString.hash(createRequest.getUserpass()));
            document.append("_userCreatedAt", LocalDateTime.now().toString());
            document.append("_userBalance", BigDecimal.valueOf(100));
            collection.insertOne(document);
        }catch (Exception exception){
            throw new DatabaseException(ReturnCode.INTERNAL_SERVER_ERROR, "Database unavailable");
        }

        return new BaseResponse(ReturnCode.CREATE_SUCCESS.getCode(), new CreateResponse("Success"));
    }

    @Override
    public FetchUserResponse getUser(String userKey) throws DatabaseException {
        User user = findUserInCollection("_userEmail", userKey);
        verifyIfUserExists(user);
        log.info(String.format("User founded with uid %s", user.get_id()));
        return userMapper.userToFetchUser(user);
    }

    @Override
    public User findUserInDatabase(String userKey) throws DatabaseException {
        return findUserInCollection("_userEmail", userKey);
    }

    @Override
    public BaseResponse depositBalance(String uid, DepositRequest depositRequest) throws DatabaseException, ValidationException {
        ObjectId objectId = new ObjectId(uid);
        User user = findUserInCollection("_id", objectId);
        verifyIfUserExists(user);
        if (depositRequest.getValue() == null || depositRequest.getValue().equals("")) {
            throw new ValidationException(ReturnCode.INVALID_PARAMETERS, "Balance is empty");
        }
        assert user != null;
        Decimal128 newBalance = new Decimal128(BigDecimal.valueOf((user.get_userBalance().bigDecimalValue()).floatValue() + depositRequest.getValue()));
        Document update = new Document("$set", new Document("_userBalance", newBalance));
        collection.updateOne(new Document("_id", objectId), update);
        return new BaseResponse(ReturnCode.SUCCESS.getCode(), null);
    }

    private User findUserInCollection(String attribute, Object searchValue) throws DatabaseException {
        log.info(String.format("Searching user with key: %s", searchValue));
        try {
            Document filter = new Document(attribute, searchValue);
            Document document = collection.find(filter).first();
            return document != null ? new User(document) : null;
        } catch (Exception e) {
            log.error(e.getLocalizedMessage());
            throw new DatabaseException(ReturnCode.INTERNAL_SERVER_ERROR, "Internal error in database");
        }
    }

    private void verifyIfUserExists(User user) throws DatabaseException {
        if (user == null){
            log.error("User not found");
            throw new DatabaseException(ReturnCode.NOT_FOUND, "User not found");
        }
    }

    private boolean isValidEmail(String email) {
        String emailRegex = "^[a-zA-Z0-9_+&*-]+(?:\\.[a-zA-Z0-9_+&*-]+)*@(?:[a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,7}$";
        return email.matches(emailRegex);
    }
}
