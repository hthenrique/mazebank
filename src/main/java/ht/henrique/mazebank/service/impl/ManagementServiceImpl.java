package ht.henrique.mazebank.service.impl;

import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoCursor;
import com.mongodb.client.MongoDatabase;
import ht.henrique.mazebank.exception.DatabaseException;
import ht.henrique.mazebank.model.BaseResponse;
import ht.henrique.mazebank.model.create.CreateRequest;
import ht.henrique.mazebank.model.create.CreateResponse;
import ht.henrique.mazebank.model.database.User;
import ht.henrique.mazebank.model.fetch.FetchUserResponse;
import ht.henrique.mazebank.model.mapper.UserMapper;
import ht.henrique.mazebank.service.ManagementService;
import lombok.extern.slf4j.Slf4j;
import org.bson.Document;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import javax.annotation.PostConstruct;
import java.math.BigDecimal;
import java.sql.Date;
import java.sql.Timestamp;
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
    public BaseResponse createUser(CreateRequest createRequest) throws DatabaseException {
         User user = findUserInCollection(createRequest.getUseremail());
         if (user != null){
             throw new DatabaseException(HttpStatus.CONFLICT, 409000, "User already exists");
         }

        try {
            Document document = new Document();
            document.append("_userName", createRequest.getUsername());
            document.append("_userEmail", createRequest.getUseremail());
            document.append("_userPass", createRequest.getUserpass());
            document.append("_userCreatedAt", LocalDateTime.now().toString());
            document.append("_userBalance", BigDecimal.valueOf(100));
            collection.insertOne(document);
        }catch (Exception exception){
            throw new DatabaseException(HttpStatus.INTERNAL_SERVER_ERROR, 500000, "Database unavailable");
        }

        return new BaseResponse(201000, new CreateResponse("Success"));
    }

    @Override
    public FetchUserResponse getUser(String userKey) throws DatabaseException {
        User user = findUserInCollection(userKey);
        if (user == null){
            log.info("User not found");
            throw new DatabaseException(HttpStatus.CONFLICT, 404000, "User not found");
        }
        return userMapper.userToFetchUser(user);
    }

    @Override
    public User findUserInDatabase(String userKey) throws DatabaseException {
        return findUserInCollection(userKey);
    }

    private User findUserInCollection(String searchValue) throws DatabaseException {
        User user = null;
        try{
            Document filter = new Document("_userEmail", searchValue);
            MongoCursor<Document> cursor = collection.find(filter).iterator();
            while (cursor.hasNext()) {
                user = new User(cursor.next());
            }
            cursor.close();
        }catch (Exception e){
            log.error(e.getLocalizedMessage());
            throw new DatabaseException(HttpStatus.INTERNAL_SERVER_ERROR, 500000, "Internal error in database");
        }
        return user;
    }
}
